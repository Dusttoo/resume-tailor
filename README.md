 resume-tailor

**resume-tailor** is a Python CLI tool that uses OpenAI’s ChatGPT to generate ATS-optimized Markdown resumes and cover letters tailored to any job description.

## Features

- **ATS-friendly** formatting with clear sections and keyword integration.
- Generates two Markdown files per job description:
  - `<employer>-resume.md`
  - `<employer>-cover.md`
- Leverages a customizable `user_profile.json` containing your background, experience, skills, and projects.
- Supports environment-based API key configuration and optional `.env` support via `python-dotenv`.

## Prerequisites

- Python 3.8 or higher  
- An OpenAI API key

## Installation

1. **Clone the repository**  
   ```bash
   git clone https://github.com/yourusername/resume-tailor.git
   cd resume-tailor
   ```

2. **Create and activate a virtual environment**  
   ```bash
   python3 -m venv venv
   source venv/bin/activate    # macOS/Linux
   .\venv\Scripts\activate     # Windows PowerShell
   ```

3. **Install dependencies**  
   ```bash
   pip install -r requirements.txt
   ```

4. *(Optional)* If you want to use a `.env` file to store your API key:
   ```bash
   pip install python-dotenv
   ```

## Configuration

1. **Set your OpenAI API key**  
   - **Environment variable** (recommended):  
     ```bash
     export OPENAI_API_KEY="sk-…"
     ```
   - **.env file** (if using `python-dotenv`):  
     Create a file named `.env` in the project root with:
     ```
     OPENAI_API_KEY=sk-…
     ```

2. **Prepare your user profile**  
   Edit or replace `user_profile.json` with your personal details, work history, skills, projects, and education.

## Usage

```bash
python generate_application.py path/to/job_description.md [--profile user_profile.json] [--outdir output_directory]
```

- **`path/to/job_description.md`**: Plain-text or Markdown file containing the job description.  
- **`--profile`**: (Optional) Path to your profile JSON. Defaults to `user_profile.json`.  
- **`--outdir`**: (Optional) Directory to save the output files. Defaults to the current directory.

## Output

After running, you’ll find two files in your output directory:
- `<employer>-resume.md`  
- `<employer>-cover.md`

## Example

```bash
export OPENAI_API_KEY="sk-…"
python generate_application.py jobs/amazon-lever.md --profile user_profile.json --outdir applications/
```

## License

MIT © Dusty Mumphrey