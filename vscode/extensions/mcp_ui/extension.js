const vscode = require('vscode');
const http = require('http');

function activate(context) {
    // Register the command to get a Jira ticket
    const getJiraTicketCommand = vscode.commands.registerCommand('mcp.getJiraTicket', async () => {
        // 1. Prompt the user for a Jira Ticket ID
        const ticketId = await vscode.window.showInputBox({
            prompt: 'Enter the Jira Ticket ID',
            placeHolder: 'e.g., PROJ-123'
        });

        if (!ticketId) {
            return; // User cancelled the input
        }

        try {
            // 2. Make a request to the local MCP server
            const ticketContext = await getTicketContextFromServer(ticketId);

            // 3. Format the context for the chat
            const formattedContext = formatTicketContext(ticketId, ticketContext);

            // 4. Send the formatted context to the active chat window
            const chatEditor = vscode.window.activeTextEditor;
            if (chatEditor && chatEditor.document.uri.scheme === 'vscode-chat') {
                 // This is a more robust way to interact with the chat
                vscode.commands.executeCommand('workbench.action.chat.open', {
                    query: formattedContext
                });
            } else {
                 // Fallback if no chat is active, though the above is preferred
                vscode.env.clipboard.writeText(formattedContext);
                vscode.window.showInformationMessage('Jira ticket context copied to clipboard.');
            }

        } catch (error) {
            vscode.window.showErrorMessage(`Failed to get Jira ticket ${ticketId}: ${error.message}`);
        }
    });

    context.subscriptions.push(getJiraTicketCommand);
}

function deactivate() {}

function formatTicketContext(ticketId, context) {
    return `
Here is the context for Jira Ticket: ${ticketId}

## Summary
${context.summary}

## Description
${context.description}

## Acceptance Criteria
${context.acceptance_criteria}

## Recent Comments
${context.comments}
    `;
}

function getTicketContextFromServer(ticketId) {
    return new Promise((resolve, reject) => {
        const req = http.request({
            hostname: '127.0.0.1',
            port: 8000,
            path: '/get-ticket-context',
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        }, res => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve(JSON.parse(data));
                } else {
                    reject(new Error(`Server returned status ${res.statusCode}: ${data}`));
                }
            });
        });
        req.on('error', e => reject(e));
        req.write(JSON.stringify({ ticket_id: ticketId }));
        req.end();
    });
}

module.exports = {
    activate,
    deactivate
};
