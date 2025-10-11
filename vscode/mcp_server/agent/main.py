import sys
import argparse
from jira_toolkit import get_jira_client, get_ticket_context
from agent import generate_dev_spec, save_spec_to_markdown

def main():
    """
    Main function to run the spec generation process.
    """
    parser = argparse.ArgumentParser(description="Generate a technical development spec from a Jira ticket.")
    parser.add_argument("ticket_id", help="The ID of the Jira ticket (e.g., PROJ-123).")
    
    args = parser.parse_args()
    ticket_id = args.ticket_id

    print(f"🚀 Starting dev spec generation for ticket: {ticket_id}")

    try:
        # 1. Get Jira context
        print("   - Connecting to Jira and fetching ticket context...")
        jira_client = get_jira_client()
        ticket_context = get_ticket_context(jira_client, ticket_id)

        if not ticket_context:
            print(f"❌ Could not retrieve context for ticket {ticket_id}. Aborting.")
            sys.exit(1)
        
        print("   - Successfully fetched Jira context.")

        # 2. Generate the dev spec using the AI agent
        print("   - Generating technical spec with AI agent (this may take a moment)...")
        spec_content = generate_dev_spec(ticket_context, ticket_id)
        print("   - Successfully generated technical spec.")

        # 3. Save the spec to a markdown file
        save_spec_to_markdown(spec_content, ticket_id)

    except Exception as e:
        print(f"\n❌ An error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
