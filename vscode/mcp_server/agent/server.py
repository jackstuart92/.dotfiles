from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

from jira_toolkit import get_jira_client, get_ticket_context

app = FastAPI(
    title="Jira MCP Server",
    description="A simple server to fetch Jira ticket context for chat.",
    version="1.0.0",
)

class TicketRequest(BaseModel):
    ticket_id: str

@app.post("/get-ticket-context")
async def get_ticket_context_endpoint(request: TicketRequest):
    """
    Receives a ticket ID, fetches its context from Jira, and returns it.
    """
    ticket_id = request.ticket_id
    print(f"🚀 Received request to fetch context for ticket: {ticket_id}")
    try:
        jira_client = get_jira_client()
        ticket_context = get_ticket_context(jira_client, ticket_id)

        if not ticket_context:
            raise HTTPException(status_code=404, detail=f"Could not retrieve context for {ticket_id}.")
        
        return ticket_context
    except Exception as e:
        print(f"❌ An error occurred: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
def read_root():
    return {"message": "Jira MCP Server is running."}

if __name__ == "__main__":
    print("Starting Jira MCP Server...")
    # Note: app_dir should point to the directory containing this script.
    uvicorn.run("server:app", host="0.0.0.0", port=8000, reload=True, app_dir="vscode/mcp_server/agent")
