#!/usr/bin/env python3
import os
import re
import argparse
import json
import openai

def load_profile(path="user_profile.json"):
    """Load your job history and skills from a JSON file."""
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def extract_employer(job_desc: str) -> str:
    """
    Heuristic to pull out the employer name from the job description.
    Falls back to 'output' if none found.
    """
    # look for Company: or About <Company>
    m = re.search(r"(?:Company|Employer|About)\s*[:\-]\s*([A-Z][A-Za-z0-9& ]+)", job_desc)
    if m:
        return re.sub(r"\s+", "-", m.group(1).strip()).lower()
    # Otherwise first Proper Noun sequence
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
            "You are a professional resume and cover-letter writer. "
            "Use the user's background (job history, skills, education, accomplishments) "
            "to craft a highly targeted, ATS-optimized markdown document. "
            "For resumes: use bullet points, clear sections (Summary, Experience, Education, Skills), "
            "and incorporate keywords from the job description. "
            "For cover letters: write a personalized letter highlighting how the user's experience "
            "matches the key requirements."
        )
    }
    # inject profile
    profile_msg = {
        "role": "system",
        "content": "User profile:\n" + json.dumps(profile, indent=2)
    }
    if mode == "resume":
        user = {
            "role": "user",
            "content": (
                "Please generate an ATS-optimized markdown resume tailored to the following job description:\n\n"
                f"{job_desc}"
            )
        }
    else:  # cover letter
        user = {
            "role": "user",
            "content": (
                "Please generate a professional cover letter in markdown addressed to the hiring manager, "
                "tailored to the following job description:\n\n"
                f"{job_desc}"
            )
        }
    return [system, profile_msg, user]

def call_openai(messages):
    resp = openai.ChatCompletion.create(
        model="gpt-4o-mini",
        messages=messages,
        temperature=0.7,
        max_tokens=1200
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
    args = parser.parse_args()

    # load inputs
    with open(args.jd, encoding="utf-8") as f:
        job_desc = f.read()
    profile = load_profile(args.profile)

    employer = extract_employer(job_desc)
    # build and send resume prompt
    resume_msgs = build_messages(profile, job_desc, mode="resume")
    resume_md = call_openai(resume_msgs)

    # build and send cover‐letter prompt
    cover_msgs = build_messages(profile, job_desc, mode="cover")
    cover_md = call_openai(cover_msgs)

    # write outputs
    resume_path = os.path.join(args.outdir, f"{employer}-resume.md")
    cover_path  = os.path.join(args.outdir, f"{employer}-cover.md")

    with open(resume_path, "w", encoding="utf-8") as f:
        f.write(resume_md)
    with open(cover_path, "w", encoding="utf-8") as f:
        f.write(cover_md)

    print(f"✅ Resume written to {resume_path}")
    print(f"✅ Cover letter written to {cover_path}")

if __name__ == "__main__":
    # ensure API key
    if not os.getenv("OPENAI_API_KEY"):
        print("⚠️  Set OPENAI_API_KEY environment variable")
        exit(1)
    main()