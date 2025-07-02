#!/usr/bin/env python3
import os
import re
import sys
import argparse
import json
import datetime
from openai import OpenAI
import subprocess
import shutil
from weasyprint import HTML

from jinja2 import Environment, FileSystemLoader

client = OpenAI()
def extract_json(content: str) -> str:
    """Strip Markdown code fences and extra text to isolate JSON."""
    m = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", content, re.DOTALL)
    if m:
        return m.group(1)
    return content

def load_profile(path="user_profile.json"):
    """Load your job history and skills from a JSON file."""
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def extract_employer(job_desc: str) -> str:
    """
    Heuristic to pull out the employer name from the job description.
    Falls back to 'output' if none found.
    """
    m = re.search(r"(?:Company|Employer|About)\s*[:\-]\s*([A-Z][A-Za-z0-9& ]+)", job_desc)
    if m:
        return re.sub(r"\s+", "-", m.group(1).strip()).lower()
    m = re.search(r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b", job_desc)
    if m:
        return re.sub(r"\s+", "-", m.group(1)).lower()
    return "output"

def build_messages(profile: dict, job_desc: str, mode: str):
    """
    Build a ChatGPT conversation:
    - mode = "resume" or "cover"
    """
    system = {
        "role": "system",
        "content": (
            "You are a professional resume and cover-letter writer. Use the user's background (job history, skills, education, accomplishments) to craft highly targeted, ATS-optimized Markdown documents. For resumes: structure with clear sections (Summary, Experience, Education, Skills), include bullet points that highlight achievements with metrics, and analyze the job description to mirror its tone and key phrases. Customize the summary to reflect how the user's unique experience and personality align with the role, incorporating humor or enthusiasm where appropriate and matching any style cues from the job description. For cover letters: write in a conversational yet professional tone, address the hiring manager, and weave in specific elements from the job posting to demonstrate genuine interest and fit."
        )
    }
    profile_msg = {
        "role": "system",
        "content": "User profile:\n" + json.dumps(profile, indent=2)
    }
    example_resume_user = {
        "role": "user",
        "content": (
            "Raw experience:\n"
            "- Senior Software Engineer at Acme Corp (2018-2023): developed Python APIs, led a team of 4, improved performance by 30%.\n"
            "Job description:\n"
            "Looking for a backend engineer to build scalable APIs and lead small teams."
        )
    }
    example_resume_assistant = {
        "role": "assistant",
        "content": (
            "### Summary\n"
            "- Backend engineer with 5 years of experience building scalable Python APIs and leading teams.\n\n"
            "### Experience\n"
            "- **Senior Software Engineer, Acme Corp (2018-2023):**\n"
            "  - Developed RESTful Python APIs serving 10k+ daily users.\n"
            "  - Led and mentored a team of 4 engineers, improving delivery speed by 25%.\n"
            "  - Optimized database queries, boosting performance by 30%."
        )
    }
    if mode == "resume":
        user = {
            "role": "user",
            "content": (
                "Please generate an ATS-optimized resume tailored to the following job description as a JSON object with these keys:\n"
                "- profile: {name, title, location, contact }\n"
                "- summary: string\n"
                "- experience: array of {title, company, dates, bullets}\n"
                "- education: array of {degree, institution, year}\n"
                "- skills: array of strings\n"
                "- certifications: array of {name, issuing_organization, date}\n"
                "- projects: array of {name, description, link?}\n\n"
                f"{job_desc}"
            )
        }
        messages = [system, profile_msg, example_resume_user, example_resume_assistant, user]
    else:  
        user = {
            "role": "user",
            "content": (
                "Please generate a professional cover letter tailored to the following job description as a JSON object with these keys:\n"
                "- date: string (Month Day, Year)\n"
                "- greeting: string (e.g., 'Dear Hiring Manager,')\n"
                "- body: array of strings (each paragraph)\n"
                "- closing: string (e.g., 'Sincerely,')\n"
                "- signature: string (user name)\n\n"
                f"{job_desc}"
            )
        }
        messages = [system, profile_msg, user]
    return messages

def call_openai(messages):
    resp = client.chat.completions.create(
        model="gpt-4o",
        messages=messages,
        temperature=0.2,
        top_p=0.9,
        max_tokens=1500
    )
    return resp.choices[0].message.content

def main():
    parser = argparse.ArgumentParser(
        description="Generate ATS-optimized resume & cover letter from a job description"
    )
    parser.add_argument("jd", help="Path to job description file (txt or md)")
    parser.add_argument(
        "--profile",
        default="user_profile.json",
        help="Path to your profile JSON file"
    )
    parser.add_argument(
        "--outdir",
        default=".",
        help="Directory to write the output markdown files"
    )
    parser.add_argument(
        "--company",
        default=None,
        help="Override employer name used for output file names"
    )
    parser.add_argument(
        "--skip-api",
        action="store_true",
        help="Skip OpenAI API calls and load existing JSON if present"
    )
    args = parser.parse_args()

    with open(args.jd, encoding="utf-8") as f:
        job_desc = f.read()
    profile = load_profile(args.profile)

    if args.company:
        employer = re.sub(r"\s+", "-", args.company.strip()).lower()
    else:
        employer = extract_employer(job_desc)

    outdir = os.path.join(args.outdir, "output")
    json_path = os.path.join(outdir, f"resume/json/{employer}-resume_data.json")
    os.makedirs(os.path.dirname(json_path), exist_ok=True)

    if not args.skip_api:
        resume_msgs = build_messages(profile, job_desc, mode="resume")
        resume_json_str = call_openai(resume_msgs)
        clean_json = extract_json(resume_json_str)
        try:
            resume_data = json.loads(clean_json)
        except json.JSONDecodeError:
            print("❌ Failed to parse JSON. Raw output:")
            print(resume_json_str)
            sys.exit(1)
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(resume_data, f, indent=2)
    else:
        if not os.path.exists(json_path):
            print(f"❌ Cannot skip API: no existing JSON at {json_path}")
            sys.exit(1)
        with open(json_path, "r", encoding="utf-8") as f:
            resume_data = json.load(f)

    html_path = os.path.join(outdir, f"resume/html/{employer}-resume.html")
    pdf_path = os.path.join(outdir, f"resume/pdf/{employer}-resume.pdf")

    env = Environment(loader=FileSystemLoader('templates'))
    template = env.get_template('resume.html')
    html = template.render(profile=profile, data=resume_data)
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html)

    os.makedirs(os.path.dirname(pdf_path), exist_ok=True)
    HTML(filename=html_path, base_url=os.getcwd()).write_pdf(pdf_path)

    cover_json_path = os.path.join(outdir, f"cover/json/{employer}-cover_data.json")
    cover_html_path = os.path.join(outdir, f"cover/html/{employer}-cover.html")
    cover_pdf_path = os.path.join(outdir, f"cover/pdf/{employer}-cover.pdf")
    os.makedirs(os.path.dirname(cover_json_path), exist_ok=True)
    os.makedirs(os.path.dirname(cover_html_path), exist_ok=True)
    os.makedirs(os.path.dirname(cover_pdf_path), exist_ok=True)

    if not args.skip_api:
        cover_msgs = build_messages(profile, job_desc, mode="cover")
        cover_json_str = call_openai(cover_msgs)
        clean_cover = extract_json(cover_json_str)
        try:
            cover_data = json.loads(clean_cover)
        except json.JSONDecodeError:
            print("❌ Failed to parse cover letter JSON. Raw output:")
            print(cover_json_str)
            sys.exit(1)
        with open(cover_json_path, "w", encoding="utf-8") as f:
            json.dump(cover_data, f, indent=2)
        cover_data['date'] = datetime.datetime.now().strftime("%B %d, %Y")
    else:
        if not os.path.exists(cover_json_path):
            print(f"❌ Cannot skip API: no existing JSON at {cover_json_path}")
            sys.exit(1)
        with open(cover_json_path, "r", encoding="utf-8") as f:
            cover_data = json.load(f)
        cover_data['date'] = datetime.datetime.now().strftime("%B %d, %Y")

    cover_template = env.get_template('cover.html')
    cover_html = cover_template.render(profile=profile, data=cover_data)
    with open(cover_html_path, "w", encoding="utf-8") as f:
        f.write(cover_html)
    HTML(string=cover_html, base_url=os.getcwd()).write_pdf(cover_pdf_path)

if __name__ == "__main__":
    if not os.getenv("OPENAI_API_KEY"):
        print("⚠️  Set OPENAI_API_KEY environment variable")
        exit(1)
    main()