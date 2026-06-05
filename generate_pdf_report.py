import json
import sys
import os

def generate_report(json_path):
    if not os.path.exists(json_path):
        print(f"Error: File {json_path} not found.")
        return

    with open(json_path, 'r') as f:
        data = json.load(f)

    # Extract metadata dynamically
    report_title = data.get("title", "Incident Report")
    source_file = data.get("source_file", "Unknown Source")
    
    html_content = f"""
    <html>
    <head>
        <style>
            table {{ width: 100%; border-collapse: collapse; }}
            th, td {{ border: 1px solid black; padding: 8px; text-align: left; }}
            th {{ background-color: #f2f2f2; }}
        </style>
    </head>
    <body>
        <h1>{report_title}</h1>
        <p><strong>Source File:</strong> {source_file}</p>
        <table>
            <tr>
                <th>Indicator</th>
                <th>Description</th>
                <th>Severity</th>
            </tr>
    """

    # Loop through indicators dynamically
    indicators = data.get("indicators", [])
    for indicator in indicators:
        name = indicator.get("name", "N/A")
        description = indicator.get("description", "N/A")
        severity = indicator.get("severity", "N/A")
        
        html_content += f"""
            <tr>
                <td>{name}</td>
                <td>{description}</td>
                <td>{severity}</td>
            </tr>
        """

    html_content += """
        </table>
    </body>
    </html>
    """

    output_filename = "report.html"
    with open(output_filename, 'w') as f:
        f.write(html_content)
    
    print(f"Report generated successfully: {output_filename}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python generate_pdf_report.py <path_to_json>")
    else:
        generate_report(sys.argv[1])
