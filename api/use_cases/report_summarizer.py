# api/use_cases/report_summarizer.py
from datetime import datetime, timedelta
import pandas as pd
from typing import List, Dict

class DailyReportSummarizer:
    def __init__(self, ollama_client, db_connector):
        self.ollama_client = ollama_client
        self.db_connector = db_connector
    
    async def summarize_operational_reports(self, date: datetime = None) -> Dict:
        """Summarize daily operational reports"""
        
        if not date:
            date = datetime.now().date()
        
        # Fetch reports from database
        reports_query = f"""
        SELECT 
            report_id,
            report_type,
            department,
            content,
            key_metrics,
            created_at
        FROM operational_reports
        WHERE DATE(created_at) = '{date}'
        ORDER BY department, report_type
        """
        
        reports_df = self.db_connector.query_sql_server(reports_query)
        
        if reports_df.empty:
            return {"summary": "No reports found for the specified date."}
        
        # Group by department
        summaries = []
        
        for dept, dept_reports in reports_df.groupby('department'):
            dept_content = f"Department: {dept}\n"
            dept_content += "Reports:\n"
            
            for _, report in dept_reports.iterrows():
                dept_content += f"- {report['report_type']}: {report['content'][:200]}...\n"
                if report['key_metrics']:
                    dept_content += f"  Key Metrics: {report['key_metrics']}\n"
            
            # Generate department summary
            dept_summary = self.ollama_client.chat(
                model="llama3.2:latest",
                messages=[
                    {
                        "role": "system",
                        "content": "You are an operations analyst. Summarize the daily reports concisely, highlighting key metrics, issues, and achievements."
                    },
                    {
                        "role": "user",
                        "content": f"Summarize these operational reports:\n\n{dept_content}"
                    }
                ],
                options={"temperature": 0.5}
            )
            
            summaries.append({
                "department": dept,
                "summary": dept_summary['message']['content'],
                "report_count": len(dept_reports)
            })
        
        # Generate executive summary
        all_summaries = "\n\n".join([f"{s['department']}:\n{s['summary']}" for s in summaries])
        
        executive_summary = self.ollama_client.chat(
            model="llama3.2:latest",
            messages=[
                {
                    "role": "system",
                    "content": "Create a concise executive summary of all departmental reports, highlighting critical issues and achievements."
                },
                {
                    "role": "user",
                    "content": f"Department summaries:\n\n{all_summaries}"
                }
            ],
            options={"temperature": 0.5}
        )
        
        return {
            "date": str(date),
            "executive_summary": executive_summary['message']['content'],
            "department_summaries": summaries,
            "total_reports": len(reports_df)
        }