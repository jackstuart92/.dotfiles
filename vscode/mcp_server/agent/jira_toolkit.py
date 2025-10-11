import os
from jira import JIRA
from dotenv import load_dotenv

def get_jira_client():
    """
    Initializes and returns a Jira client based on the auth type specified in .env.
    Supports 'cloud' (email + API token) and 'server' (username + PAT/password).
    """
    load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

    auth_type = os.getenv("JIRA_AUTH_TYPE", "cloud").lower()
    jira_server = os.getenv("JIRA_SERVER")

    if not jira_server:
        raise ValueError("JIRA_SERVER must be set in the .env file.")

    options = {'server': jira_server}
    
    if auth_type == 'cloud':
        jira_email = os.getenv("JIRA_EMAIL")
        jira_token = os.getenv("JIRA_TOKEN")
        if not all([jira_email, jira_token]):
            raise ValueError("For JIRA_AUTH_TYPE='cloud', JIRA_EMAIL and JIRA_TOKEN must be set.")
        auth = (jira_email, jira_token)
        print("Authenticating with Jira Cloud (email/token)...")

    elif auth_type == 'server':
        jira_username = os.getenv("JIRA_USERNAME")
        jira_pat = os.getenv("JIRA_PAT")
        if not all([jira_username, jira_pat]):
            raise ValueError("For JIRA_AUTH_TYPE='server', JIRA_USERNAME and JIRA_PAT must be set.")
        auth = (jira_username, jira_pat)
        print("Authenticating with Jira Server (username/pat)...")
        
    else:
        raise ValueError(f"Invalid JIRA_AUTH_TYPE '{auth_type}'. Must be 'cloud' or 'server'.")

    return JIRA(options, basic_auth=auth)

def get_ticket_context(jira_client, ticket_id):
    """
    Gathers the summary, description, acceptance criteria, and comments for a specific ticket.
    """
    try:
        issue = jira_client.issue(ticket_id)
        
        # Note: 'Acceptance Criteria' is often a custom field. 
        # You may need to find its ID in your Jira instance (e.g., 'customfield_10027').
        # For now, we'll try to access it by its common name and handle if it's not found.
        acceptance_criteria = "Not specified"
        for field_name in issue.raw['fields']:
            if 'acceptance criteria' in field_name.lower():
                acceptance_criteria = issue.raw['fields'][field_name]
                if acceptance_criteria:
                    break
        
        comments = [
            f"Author: {comment.author.displayName}\nDate: {comment.created.split('T')[0]}\n{comment.body}\n"
            for comment in issue.fields.comment.comments
        ]
        
        context = {
            "summary": issue.fields.summary,
            "description": issue.fields.description or "No description provided.",
            "acceptance_criteria": acceptance_criteria,
            "comments": "\n---\n".join(comments) if comments else "No comments found."
        }
        return context
    except Exception as e:
        print(f"Error fetching ticket {ticket_id}: {e}")
        return None

if __name__ == '__main__':
    # This is a simple test to verify the connection and data fetching.
    # To run: python mcp_agent/jira_toolkit.py YOUR-TICKET-ID
    import sys
    if len(sys.argv) > 1:
        ticket_id = sys.argv[1]
        print(f"Fetching context for ticket: {ticket_id}")
        try:
            client = get_jira_client()
            ticket_context = get_ticket_context(client, ticket_id)
            if ticket_context:
                print("\n--- Ticket Context ---")
                for key, value in ticket_context.items():
                    print(f"## {key.replace('_', ' ').title()}:\n{value}\n")
                print("----------------------")
        except ValueError as e:
            print(f"Configuration error: {e}")
    else:
        print("Usage: python mcp_agent/jira_toolkit.py <TICKET-ID>")
