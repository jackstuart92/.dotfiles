const vscode = require('vscode');
const fs = require('fs');
const path = require('path');

let statusBarItem;
let personas = {};

async function activate(context) {
    // --- 1. Setup and Initialization ---

    // Define paths relative to the workspace root
    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders) {
        vscode.window.showErrorMessage('Persona Switcher requires an open workspace.');
        return;
    }
    const workspaceRoot = workspaceFolders[0].uri.fsPath;
    const personasDir = path.join(workspaceRoot, 'vscode', 'personas');
    const copilotInstructionsFile = path.join(workspaceRoot, '.github', 'copilot-instructions.md');

    // Load personas from the directory
    await loadPersonas(personasDir);

    // Create a status bar item
    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.command = 'persona.selectPersona';
    updateStatusBar('default'); // Start with default
    statusBarItem.tooltip = 'Select a Chat Persona';
    statusBarItem.show();
    context.subscriptions.push(statusBarItem);

    // --- 2. Command Registration ---

    const selectPersonaCommand = vscode.commands.registerCommand('persona.selectPersona', async () => {
        const personaName = await vscode.window.showQuickPick(Object.keys(personas), {
            placeHolder: 'Choose a persona for the Copilot assistant'
        });

        if (personaName && personas[personaName]) {
            try {
                // Read the selected persona's content
                const personaContent = await fs.promises.readFile(personas[personaName], 'utf8');

                // Generate the header for the instructions file
                const header = `This file is managed by the Persona Switcher extension.
The content of this file is automatically overwritten when you select a new persona from the status bar.
To add or edit personas, see the files in the 'vscode/personas/' directory.

---

`;
                // Write the new content to the copilot-instructions.md file
                await fs.promises.writeFile(copilotInstructionsFile, header + personaContent);

                updateStatusBar(personaName);
                vscode.window.showInformationMessage(`Persona changed to: ${personaName}`);
            } catch (error) {
                vscode.window.showErrorMessage(`Failed to switch persona: ${error.message}`);
            }
        }
    });

    context.subscriptions.push(selectPersonaCommand);
}

// --- 3. Helper Functions ---

async function loadPersonas(personasDir) {
    try {
        const files = await fs.promises.readdir(personasDir);
        personas = {}; // Clear existing personas
        for (const file of files) {
            if (path.extname(file) === '.md') {
                const name = path.basename(file, '.md');
                // Format the name for display (e.g., 'principal-engineer' -> 'Principal Engineer')
                const displayName = name.split('-').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
                personas[displayName] = path.join(personasDir, file);
            }
        }
    } catch (error) {
        vscode.window.showErrorMessage(`Failed to load personas: ${error.message}`);
        personas = {}; // Ensure personas is empty on failure
    }
}

function updateStatusBar(personaName) {
    if (statusBarItem) {
        // Capitalize the first letter for display
        const displayName = personaName.charAt(0).toUpperCase() + personaName.slice(1);
        statusBarItem.text = `$(hubot) Persona: ${displayName}`;
    }
}

function deactivate() {
    if (statusBarItem) {
        statusBarItem.dispose();
    }
}

module.exports = {
    activate,
    deactivate
};
