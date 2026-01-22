/**
 * SuperClaude Telegram Bot
 * 
 * Control Claude Code sessions from Telegram with:
 * - Multiple concurrent sessions per project/worktree
 * - Voice message transcription
 * - Image input
 * - Session switching
 * - Real-time notifications
 * 
 * Prerequisites:
 *   - Node.js 20+
 *   - Claude Code CLI installed
 *   - Telegram Bot Token (from @BotFather)
 *   - OpenAI API key (for Whisper transcription)
 */

import Anthropic from '@anthropic-ai/sdk';
import { spawn, exec } from 'child_process';
import { Telegraf, Markup } from 'telegraf';
import { message } from 'telegraf/filters';
import fs from 'fs/promises';
import path from 'path';

// ─────────────────────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────────────────────

const config = {
  telegram: {
    token: process.env.TELEGRAM_BOT_TOKEN,
    allowedUsers: (process.env.TELEGRAM_ALLOWED_USERS || '').split(',').map(Number),
  },
  whisper: {
    // Local Whisper API (no OpenAI needed!)
    apiUrl: process.env.WHISPER_API_URL || 'http://whisper:8787',
  },
  claude: {
    projectsRoot: process.env.PROJECTS_ROOT || '/workspace/projects',
  },
  paths: {
    sessions: '/tmp/superclaude-sessions',
    transcripts: '/tmp/superclaude-transcripts',
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface Session {
  id: string;
  project: string;
  worktree?: string;
  cwd: string;
  status: 'idle' | 'working' | 'waiting';
  lastMessage?: string;
  lastActivity: Date;
  conversationId?: string;
}

interface UserState {
  activeSession?: string;
  sessions: Map<string, Session>;
}

// ─────────────────────────────────────────────────────────────────────────────
// State Management
// ─────────────────────────────────────────────────────────────────────────────

const userStates = new Map<number, UserState>();
const claudeProcesses = new Map<string, any>(); // session ID -> Claude SDK instance

function getUserState(userId: number): UserState {
  if (!userStates.has(userId)) {
    userStates.set(userId, { sessions: new Map() });
  }
  return userStates.get(userId)!;
}

// ─────────────────────────────────────────────────────────────────────────────
// Initialize Services
// ─────────────────────────────────────────────────────────────────────────────

const bot = new Telegraf(config.telegram.token!);

// Auth middleware
bot.use(async (ctx, next) => {
  const userId = ctx.from?.id;
  if (!userId || !config.telegram.allowedUsers.includes(userId)) {
    await ctx.reply('⛔ Unauthorized. Your user ID: ' + userId);
    return;
  }
  return next();
});

// ─────────────────────────────────────────────────────────────────────────────
// Voice Transcription (Local Whisper)
// ─────────────────────────────────────────────────────────────────────────────

async function transcribeVoice(fileUrl: string): Promise<string> {
  // Use local Whisper API
  const response = await fetch(`${config.whisper.apiUrl}/transcribe/url`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url: fileUrl }),
  });
  
  if (!response.ok) {
    throw new Error(`Whisper API error: ${response.status}`);
  }
  
  const result = await response.json();
  return result.text;
}

// ─────────────────────────────────────────────────────────────────────────────
// Project Discovery
// ─────────────────────────────────────────────────────────────────────────────

async function listProjects(): Promise<string[]> {
  const entries = await fs.readdir(config.claude.projectsRoot, { withFileTypes: true });
  return entries
    .filter(e => e.isDirectory() && !e.name.startsWith('.'))
    .map(e => e.name);
}

async function listWorktrees(project: string): Promise<string[]> {
  const projectPath = path.join(config.claude.projectsRoot, project);
  
  return new Promise((resolve) => {
    exec(`cd "${projectPath}" && git worktree list --porcelain 2>/dev/null`, (err, stdout) => {
      if (err) {
        resolve(['main']);
        return;
      }
      
      const worktrees = stdout
        .split('\n')
        .filter(line => line.startsWith('worktree '))
        .map(line => {
          const fullPath = line.replace('worktree ', '');
          return path.basename(fullPath);
        });
      
      resolve(worktrees.length ? worktrees : ['main']);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Management
// ─────────────────────────────────────────────────────────────────────────────

function generateSessionId(project: string, worktree?: string): string {
  const base = worktree ? `${project}-${worktree}` : project;
  return `${base}-${Date.now().toString(36)}`;
}

async function createSession(userId: number, project: string, worktree?: string): Promise<Session> {
  const state = getUserState(userId);
  const sessionId = generateSessionId(project, worktree);
  
  let cwd = path.join(config.claude.projectsRoot, project);
  if (worktree && worktree !== 'main') {
    // Check if worktree exists
    const worktreePath = path.join(config.claude.projectsRoot, `${project}-${worktree}`);
    try {
      await fs.access(worktreePath);
      cwd = worktreePath;
    } catch {
      // Worktree doesn't exist, use main project
    }
  }
  
  const session: Session = {
    id: sessionId,
    project,
    worktree,
    cwd,
    status: 'idle',
    lastActivity: new Date(),
  };
  
  state.sessions.set(sessionId, session);
  state.activeSession = sessionId;
  
  return session;
}

// ─────────────────────────────────────────────────────────────────────────────
// Claude Code Integration
// ─────────────────────────────────────────────────────────────────────────────

async function sendToClaudeCode(
  userId: number,
  sessionId: string,
  message: string,
  images?: string[]
): Promise<string> {
  const state = getUserState(userId);
  const session = state.sessions.get(sessionId);
  
  if (!session) {
    throw new Error('Session not found');
  }
  
  session.status = 'working';
  session.lastActivity = new Date();
  
  // Build the prompt
  let prompt = message;
  
  // Use Claude Code CLI with SDK
  return new Promise((resolve, reject) => {
    const args = [
      '--print',
      '--output-format', 'text',
      '--cwd', session.cwd,
    ];
    
    // Add images if present
    if (images && images.length > 0) {
      for (const img of images) {
        args.push('--image', img);
      }
    }
    
    args.push(prompt);
    
    const claude = spawn('claude', args, {
      cwd: session.cwd,
      env: {
        ...process.env,
        CLAUDE_SESSION_ID: sessionId,
      }
    });
    
    let output = '';
    let error = '';
    
    claude.stdout.on('data', (data) => {
      output += data.toString();
    });
    
    claude.stderr.on('data', (data) => {
      error += data.toString();
    });
    
    claude.on('close', (code) => {
      session.status = 'idle';
      session.lastMessage = output.slice(-500); // Keep last 500 chars
      
      if (code === 0) {
        resolve(output);
      } else {
        reject(new Error(error || `Claude exited with code ${code}`));
      }
    });
    
    // Store process reference
    claudeProcesses.set(sessionId, claude);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Telegram Command Handlers
// ─────────────────────────────────────────────────────────────────────────────

// /start - Welcome message
bot.command('start', async (ctx) => {
  await ctx.reply(
    `🤖 *SuperClaude Bot*\n\n` +
    `Control your Claude Code sessions from Telegram!\n\n` +
    `*Commands:*\n` +
    `/new - Create new session\n` +
    `/sessions - List active sessions\n` +
    `/switch - Switch to another session\n` +
    `/status - Current session status\n` +
    `/last - Show last Claude message\n` +
    `/stop - Stop current session\n` +
    `/projects - List available projects\n\n` +
    `*Input:*\n` +
    `• Send text to chat with Claude\n` +
    `• Send voice message (auto-transcribed)\n` +
    `• Send image with caption\n`,
    { parse_mode: 'Markdown' }
  );
});

// /projects - List available projects
bot.command('projects', async (ctx) => {
  const projects = await listProjects();
  
  if (projects.length === 0) {
    await ctx.reply('No projects found in ' + config.claude.projectsRoot);
    return;
  }
  
  const buttons = projects.map(p => [Markup.button.callback(`📁 ${p}`, `project:${p}`)]);
  
  await ctx.reply(
    '📂 *Available Projects*\n\nSelect a project to start a session:',
    {
      parse_mode: 'Markdown',
      ...Markup.inlineKeyboard(buttons)
    }
  );
});

// /new - Create new session
bot.command('new', async (ctx) => {
  await ctx.reply(
    '🆕 *New Session*\n\nSelect a project:',
    { parse_mode: 'Markdown' }
  );
  
  // Trigger project selection
  await bot.handleUpdate({
    ...ctx.update,
    message: { ...ctx.message, text: '/projects' }
  } as any);
});

// Handle project selection
bot.action(/^project:(.+)$/, async (ctx) => {
  const project = ctx.match[1];
  const worktrees = await listWorktrees(project);
  
  if (worktrees.length <= 1) {
    // No worktrees, create session directly
    const session = await createSession(ctx.from!.id, project);
    await ctx.editMessageText(
      `✅ Session created!\n\n` +
      `📁 Project: *${project}*\n` +
      `🆔 Session: \`${session.id}\`\n\n` +
      `Send a message to start chatting with Claude.`,
      { parse_mode: 'Markdown' }
    );
  } else {
    // Show worktree selection
    const buttons = worktrees.map(w => 
      [Markup.button.callback(`🌿 ${w}`, `worktree:${project}:${w}`)]
    );
    buttons.push([Markup.button.callback('➕ Create new worktree', `newworktree:${project}`)]);
    
    await ctx.editMessageText(
      `📁 *${project}*\n\nSelect a worktree:`,
      {
        parse_mode: 'Markdown',
        ...Markup.inlineKeyboard(buttons)
      }
    );
  }
});

// Handle worktree selection
bot.action(/^worktree:(.+):(.+)$/, async (ctx) => {
  const project = ctx.match[1];
  const worktree = ctx.match[2];
  
  const session = await createSession(ctx.from!.id, project, worktree);
  
  await ctx.editMessageText(
    `✅ Session created!\n\n` +
    `📁 Project: *${project}*\n` +
    `🌿 Worktree: *${worktree}*\n` +
    `🆔 Session: \`${session.id}\`\n\n` +
    `Send a message to start chatting with Claude.`,
    { parse_mode: 'Markdown' }
  );
});

// /sessions - List active sessions
bot.command('sessions', async (ctx) => {
  const state = getUserState(ctx.from!.id);
  
  if (state.sessions.size === 0) {
    await ctx.reply('No active sessions. Use /new to create one.');
    return;
  }
  
  const buttons = Array.from(state.sessions.values()).map(s => {
    const icon = s.id === state.activeSession ? '▶️' : '⏸️';
    const status = s.status === 'working' ? '🔄' : s.status === 'waiting' ? '⏳' : '💤';
    const label = s.worktree ? `${s.project}/${s.worktree}` : s.project;
    return [Markup.button.callback(`${icon} ${label} ${status}`, `switch:${s.id}`)];
  });
  
  await ctx.reply(
    `📋 *Active Sessions*\n\n` +
    `▶️ = active, 🔄 = working, ⏳ = waiting, 💤 = idle`,
    {
      parse_mode: 'Markdown',
      ...Markup.inlineKeyboard(buttons)
    }
  );
});

// Handle session switch
bot.action(/^switch:(.+)$/, async (ctx) => {
  const sessionId = ctx.match[1];
  const state = getUserState(ctx.from!.id);
  
  if (!state.sessions.has(sessionId)) {
    await ctx.answerCbQuery('Session not found');
    return;
  }
  
  state.activeSession = sessionId;
  const session = state.sessions.get(sessionId)!;
  
  await ctx.editMessageText(
    `✅ Switched to session\n\n` +
    `📁 Project: *${session.project}*\n` +
    `🌿 Worktree: *${session.worktree || 'main'}*\n` +
    `📊 Status: ${session.status}\n\n` +
    `Send a message to continue chatting.`,
    { parse_mode: 'Markdown' }
  );
});

// /status - Current session status
bot.command('status', async (ctx) => {
  const state = getUserState(ctx.from!.id);
  
  if (!state.activeSession) {
    await ctx.reply('No active session. Use /new to create one.');
    return;
  }
  
  const session = state.sessions.get(state.activeSession)!;
  const statusEmoji = {
    idle: '💤',
    working: '🔄',
    waiting: '⏳'
  };
  
  await ctx.reply(
    `📊 *Session Status*\n\n` +
    `🆔 ID: \`${session.id}\`\n` +
    `📁 Project: *${session.project}*\n` +
    `🌿 Worktree: *${session.worktree || 'main'}*\n` +
    `📂 Path: \`${session.cwd}\`\n` +
    `${statusEmoji[session.status]} Status: ${session.status}\n` +
    `⏰ Last activity: ${session.lastActivity.toLocaleTimeString()}`,
    { parse_mode: 'Markdown' }
  );
});

// /last - Show last Claude message
bot.command('last', async (ctx) => {
  const state = getUserState(ctx.from!.id);
  
  if (!state.activeSession) {
    await ctx.reply('No active session.');
    return;
  }
  
  const session = state.sessions.get(state.activeSession)!;
  
  if (!session.lastMessage) {
    await ctx.reply('No messages in this session yet.');
    return;
  }
  
  await ctx.reply(
    `💬 *Last message from Claude:*\n\n${session.lastMessage}`,
    { parse_mode: 'Markdown' }
  );
});

// /stop - Stop current session
bot.command('stop', async (ctx) => {
  const state = getUserState(ctx.from!.id);
  
  if (!state.activeSession) {
    await ctx.reply('No active session.');
    return;
  }
  
  const session = state.sessions.get(state.activeSession)!;
  
  // Kill Claude process if running
  const process = claudeProcesses.get(session.id);
  if (process) {
    process.kill();
    claudeProcesses.delete(session.id);
  }
  
  state.sessions.delete(session.id);
  state.activeSession = state.sessions.size > 0 
    ? state.sessions.keys().next().value 
    : undefined;
  
  await ctx.reply(`✅ Session \`${session.id}\` stopped.`, { parse_mode: 'Markdown' });
});

// ─────────────────────────────────────────────────────────────────────────────
// Message Handlers
// ─────────────────────────────────────────────────────────────────────────────

// Handle text messages
bot.on(message('text'), async (ctx) => {
  // Ignore commands
  if (ctx.message.text.startsWith('/')) return;
  
  const state = getUserState(ctx.from!.id);
  
  if (!state.activeSession) {
    await ctx.reply(
      '⚠️ No active session.\n\nUse /new to create a session first.',
      Markup.inlineKeyboard([[Markup.button.callback('🆕 New Session', 'cmd:new')]])
    );
    return;
  }
  
  const statusMsg = await ctx.reply('🔄 Sending to Claude...');
  
  try {
    const response = await sendToClaudeCode(
      ctx.from!.id,
      state.activeSession,
      ctx.message.text
    );
    
    // Split long messages
    const chunks = response.match(/[\s\S]{1,4000}/g) || [response];
    
    for (const chunk of chunks) {
      await ctx.reply(chunk);
    }
    
    await ctx.telegram.deleteMessage(ctx.chat.id, statusMsg.message_id);
  } catch (error: any) {
    await ctx.telegram.editMessageText(
      ctx.chat.id,
      statusMsg.message_id,
      undefined,
      `❌ Error: ${error.message}`
    );
  }
});

// Handle voice messages
bot.on(message('voice'), async (ctx) => {
  const state = getUserState(ctx.from!.id);
  
  if (!state.activeSession) {
    await ctx.reply('⚠️ No active session. Use /new first.');
    return;
  }
  
  const statusMsg = await ctx.reply('🎤 Transcribing voice message...');
  
  try {
    // Get file URL
    const file = await ctx.telegram.getFile(ctx.message.voice.file_id);
    const fileUrl = `https://api.telegram.org/file/bot${config.telegram.token}/${file.file_path}`;
    
    // Transcribe
    const transcription = await transcribeVoice(fileUrl);
    
    await ctx.telegram.editMessageText(
      ctx.chat.id,
      statusMsg.message_id,
      undefined,
      `🎤 *Transcribed:* "${transcription}"\n\n🔄 Sending to Claude...`,
      { parse_mode: 'Markdown' }
    );
    
    // Send to Claude
    const response = await sendToClaudeCode(
      ctx.from!.id,
      state.activeSession,
      transcription
    );
    
    const chunks = response.match(/[\s\S]{1,4000}/g) || [response];
    for (const chunk of chunks) {
      await ctx.reply(chunk);
    }
    
    await ctx.telegram.deleteMessage(ctx.chat.id, statusMsg.message_id);
  } catch (error: any) {
    await ctx.telegram.editMessageText(
      ctx.chat.id,
      statusMsg.message_id,
      undefined,
      `❌ Error: ${error.message}`
    );
  }
});

// Handle photos
bot.on(message('photo'), async (ctx) => {
  const state = getUserState(ctx.from!.id);
  
  if (!state.activeSession) {
    await ctx.reply('⚠️ No active session. Use /new first.');
    return;
  }
  
  const caption = ctx.message.caption || 'What is in this image?';
  const statusMsg = await ctx.reply('🖼️ Processing image...');
  
  try {
    // Get largest photo
    const photo = ctx.message.photo[ctx.message.photo.length - 1];
    const file = await ctx.telegram.getFile(photo.file_id);
    const fileUrl = `https://api.telegram.org/file/bot${config.telegram.token}/${file.file_path}`;
    
    // Download and convert to base64
    const response = await fetch(fileUrl);
    const buffer = Buffer.from(await response.arrayBuffer());
    const base64 = buffer.toString('base64');
    const tempPath = `/tmp/image-${Date.now()}.jpg`;
    await fs.writeFile(tempPath, buffer);
    
    await ctx.telegram.editMessageText(
      ctx.chat.id,
      statusMsg.message_id,
      undefined,
      `🖼️ Image received\n🔄 Sending to Claude with: "${caption}"`,
    );
    
    // Send to Claude with image
    const claudeResponse = await sendToClaudeCode(
      ctx.from!.id,
      state.activeSession,
      caption,
      [tempPath]
    );
    
    const chunks = claudeResponse.match(/[\s\S]{1,4000}/g) || [claudeResponse];
    for (const chunk of chunks) {
      await ctx.reply(chunk);
    }
    
    await ctx.telegram.deleteMessage(ctx.chat.id, statusMsg.message_id);
    await fs.unlink(tempPath).catch(() => {});
  } catch (error: any) {
    await ctx.telegram.editMessageText(
      ctx.chat.id,
      statusMsg.message_id,
      undefined,
      `❌ Error: ${error.message}`
    );
  }
});

// Handle documents (for code files, etc.)
bot.on(message('document'), async (ctx) => {
  const state = getUserState(ctx.from!.id);
  
  if (!state.activeSession) {
    await ctx.reply('⚠️ No active session. Use /new first.');
    return;
  }
  
  const session = state.sessions.get(state.activeSession)!;
  const caption = ctx.message.caption || 'I uploaded a file. Please analyze it.';
  const statusMsg = await ctx.reply('📄 Downloading file...');
  
  try {
    const file = await ctx.telegram.getFile(ctx.message.document.file_id);
    const fileUrl = `https://api.telegram.org/file/bot${config.telegram.token}/${file.file_path}`;
    
    // Download file
    const response = await fetch(fileUrl);
    const buffer = Buffer.from(await response.arrayBuffer());
    
    // Save to session directory
    const fileName = ctx.message.document.file_name || 'uploaded-file';
    const filePath = path.join(session.cwd, fileName);
    await fs.writeFile(filePath, buffer);
    
    await ctx.telegram.editMessageText(
      ctx.chat.id,
      statusMsg.message_id,
      undefined,
      `📄 File saved to: \`${fileName}\`\n🔄 Sending to Claude...`,
      { parse_mode: 'Markdown' }
    );
    
    // Tell Claude about the file
    const claudeResponse = await sendToClaudeCode(
      ctx.from!.id,
      state.activeSession,
      `I uploaded a file "${fileName}" to the current directory. ${caption}`
    );
    
    const chunks = claudeResponse.match(/[\s\S]{1,4000}/g) || [claudeResponse];
    for (const chunk of chunks) {
      await ctx.reply(chunk);
    }
    
    await ctx.telegram.deleteMessage(ctx.chat.id, statusMsg.message_id);
  } catch (error: any) {
    await ctx.telegram.editMessageText(
      ctx.chat.id,
      statusMsg.message_id,
      undefined,
      `❌ Error: ${error.message}`
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Callback Handlers
// ─────────────────────────────────────────────────────────────────────────────

bot.action('cmd:new', async (ctx) => {
  await ctx.answerCbQuery();
  const projects = await listProjects();
  
  const buttons = projects.map(p => [Markup.button.callback(`📁 ${p}`, `project:${p}`)]);
  
  await ctx.editMessageText(
    '📂 Select a project:',
    Markup.inlineKeyboard(buttons)
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Notification Receiver (HTTP endpoint for hooks)
// ─────────────────────────────────────────────────────────────────────────────

import express from 'express';

const app = express();
app.use(express.json());

app.post('/notify', async (req, res) => {
  const { userId, sessionId, event, message } = req.body;
  
  if (!userId || !config.telegram.allowedUsers.includes(userId)) {
    res.status(403).json({ error: 'Unauthorized' });
    return;
  }
  
  const emoji = {
    stop: '✅',
    notification: '🔔',
    error: '❌',
    start: '🚀'
  };
  
  try {
    await bot.telegram.sendMessage(
      userId,
      `${emoji[event as keyof typeof emoji] || '💬'} *${event.toUpperCase()}*\n\n` +
      `Session: \`${sessionId}\`\n` +
      `${message}`,
      {
        parse_mode: 'Markdown',
        ...Markup.inlineKeyboard([
          [Markup.button.callback('📋 View Status', `status:${sessionId}`)],
          [Markup.button.callback('🔄 Switch to Session', `switch:${sessionId}`)]
        ])
      }
    );
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Start Bot
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  // Ensure directories exist
  await fs.mkdir(config.paths.sessions, { recursive: true });
  await fs.mkdir(config.paths.transcripts, { recursive: true });
  
  // Start HTTP server for notifications
  const PORT = process.env.PORT || 3847;
  app.listen(PORT, () => {
    console.log(`🔔 Notification server listening on port ${PORT}`);
  });
  
  // Start bot
  await bot.launch();
  console.log('🤖 SuperClaude Telegram Bot started!');
  console.log(`📱 Allowed users: ${config.telegram.allowedUsers.join(', ')}`);
}

// Graceful shutdown
process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));

main().catch(console.error);
