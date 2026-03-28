# Paperclip Agent Adapter Configurations

Use these when creating/updating agents in the Paperclip dashboard
(Company → Agents → Create/Edit).

## Shared Skills Directory Structure

Place all skills in a single directory that every agent can access:

```
axiom-company/
├── agents/
│   ├── cto/AGENTS.md
│   ├── app-dev/AGENTS.md
│   ├── qa/AGENTS.md
│   ├── devops/AGENTS.md
│   ├── ai-ml/AGENTS.md
│   └── dba/AGENTS.md
└── skills/
    ├── cloudflare-stack/SKILL.md     ← shared (all agents)
    ├── git-workflow/SKILL.md         ← shared (all agents)
    ├── automation-governance/SKILL.md ← shared (all agents)
    ├── software-architect/SKILL.md
    ├── sveltekit-frontend/SKILL.md
    ├── cf-workers-api/SKILL.md
    ├── code-reviewer/SKILL.md
    ├── drizzle-schema/SKILL.md
    ├── reality-checker/SKILL.md
    ├── visual-qa/SKILL.md
    ├── a11y-auditor/SKILL.md
    ├── test-analyzer/SKILL.md
    ├── api-tester/SKILL.md
    ├── perf-benchmarker/SKILL.md
    ├── e2e-playwright/SKILL.md
    ├── axiom-cicd/
    │   ├── SKILL.md
    │   └── references/ (12 files)
    ├── devops-automator/SKILL.md
    ├── sre-ops/SKILL.md
    ├── security-engineer/SKILL.md
    ├── ai-engineer/SKILL.md
    ├── workers-ai/SKILL.md
    ├── voice-ai-stack/SKILL.md
    ├── data-remediation/SKILL.md
    ├── d1-optimizer/SKILL.md
    └── d1-time-travel/SKILL.md

```

---

## 1. CTO Agent

```json
{
  "name": "CTO",
  "title": "Chief Technology Officer",
  "role": "executive",
  "adapterType": "claude_local",
  "adapterConfig": {
    "model": "claude-sonnet-4-20250514",
    "cwd": "/path/to/axiom-company",
    "instructionsFilePath": "/path/to/axiom-company/agents/cto/AGENTS.md",
    "args": ["--add-dir", "/path/to/axiom-company/skills"],
    "timeoutSec": 900,
    "graceSec": 15,
    "maxTurnsPerRun": 20,
    "dangerouslySkipPermissions": true
  },
  "runtimeConfig": {
    "heartbeat": {
      "enabled": true,
      "intervalSec": 600,
      "wakeOnDemand": true,
      "cooldownSec": 10,
      "maxConcurrentRuns": 1
    },
    "budget": {
      "monthlyCents": 5000
    }
  }
}
```

## 2. App Dev Lead Agent

```json
{
  "name": "App Dev Lead",
  "title": "Application Development Lead",
  "role": "manager",
  "reportsTo": "CTO",
  "adapterType": "claude_local",
  "adapterConfig": {
    "model": "claude-sonnet-4-20250514",
    "cwd": "/path/to/axiom-company",
    "instructionsFilePath": "/path/to/axiom-company/agents/app-dev/AGENTS.md",
    "args": ["--add-dir", "/path/to/axiom-company/skills"],
    "timeoutSec": 900,
    "graceSec": 15,
    "maxTurnsPerRun": 30,
    "dangerouslySkipPermissions": true
  },
  "runtimeConfig": {
    "heartbeat": {
      "enabled": true,
      "intervalSec": 600,
      "wakeOnDemand": true,
      "cooldownSec": 10,
      "maxConcurrentRuns": 1
    },
    "budget": {
      "monthlyCents": 3000
    }
  }
}
```

## 3. QA Lead Agent

```json
{
  "name": "QA Lead",
  "title": "Quality Assurance Lead",
  "role": "manager",
  "reportsTo": "CTO",
  "adapterType": "claude_local",
  "adapterConfig": {
    "model": "claude-haiku-4-5-20251001",
    "cwd": "/path/to/axiom-company",
    "instructionsFilePath": "/path/to/axiom-company/agents/qa/AGENTS.md",
    "args": ["--add-dir", "/path/to/axiom-company/skills"],
    "timeoutSec": 900,
    "graceSec": 15,
    "maxTurnsPerRun": 20,
    "dangerouslySkipPermissions": true
  },
  "runtimeConfig": {
    "heartbeat": {
      "enabled": false,
      "intervalSec": 86400,
      "wakeOnDemand": true,
      "cooldownSec": 10,
      "maxConcurrentRuns": 1
    },
    "budget": {
      "monthlyCents": 2000
    }
  }
}
```

## 4. DevOps Lead Agent (UPDATE EXISTING)

Update the existing DevOps agent — do NOT delete and recreate:

```json
{
  "name": "DevOps Lead",
  "title": "DevOps Lead",
  "role": "manager",
  "reportsTo": "CTO",
  "adapterType": "claude_local",
  "adapterConfig": {
    "model": "claude-sonnet-4-20250514",
    "cwd": "/path/to/axiom-company",
    "instructionsFilePath": "/path/to/axiom-company/agents/devops/AGENTS.md",
    "args": ["--add-dir", "/path/to/axiom-company/skills"],
    "timeoutSec": 900,
    "graceSec": 15,
    "maxTurnsPerRun": 30,
    "dangerouslySkipPermissions": true
  },
  "runtimeConfig": {
    "heartbeat": {
      "enabled": true,
      "intervalSec": 600,
      "wakeOnDemand": true,
      "cooldownSec": 10,
      "maxConcurrentRuns": 1
    },
    "budget": {
      "monthlyCents": 3000
    }
  }
}
```

## 5. AI/ML Lead Agent

```json
{
  "name": "AI/ML Lead",
  "title": "AI and Machine Learning Lead",
  "role": "manager",
  "reportsTo": "CTO",
  "adapterType": "claude_local",
  "adapterConfig": {
    "model": "claude-sonnet-4-20250514",
    "cwd": "/path/to/axiom-company",
    "instructionsFilePath": "/path/to/axiom-company/agents/ai-ml/AGENTS.md",
    "args": ["--add-dir", "/path/to/axiom-company/skills"],
    "timeoutSec": 900,
    "graceSec": 15,
    "maxTurnsPerRun": 30,
    "dangerouslySkipPermissions": true
  },
  "runtimeConfig": {
    "heartbeat": {
      "enabled": true,
      "intervalSec": 600,
      "wakeOnDemand": true,
      "cooldownSec": 10,
      "maxConcurrentRuns": 1
    },
    "budget": {
      "monthlyCents": 3000
    }
  }
}
```

## 6. DBA Lead Agent

```json
{
  "name": "DBA Lead",
  "title": "Database Administrator Lead",
  "role": "manager",
  "reportsTo": "CTO",
  "adapterType": "claude_local",
  "adapterConfig": {
    "model": "claude-haiku-4-5-20251001",
    "cwd": "/path/to/axiom-company",
    "instructionsFilePath": "/path/to/axiom-company/agents/dba/AGENTS.md",
    "args": ["--add-dir", "/path/to/axiom-company/skills"],
    "timeoutSec": 900,
    "graceSec": 15,
    "maxTurnsPerRun": 20,
    "dangerouslySkipPermissions": true
  },
  "runtimeConfig": {
    "heartbeat": {
      "enabled": false,
      "intervalSec": 86400,
      "wakeOnDemand": true,
      "cooldownSec": 10,
      "maxConcurrentRuns": 1
    },
    "budget": {
      "monthlyCents": 1500
    }
  }
}
```

---

## Update vs Create Summary

| Agent | Action | Notes |
|-------|--------|-------|
| CTO | CREATE | New agent |
| App Dev Lead | CREATE | New agent |
| QA Lead | CREATE | New agent |
| DevOps Lead | UPDATE | Update instructionsFilePath + args only |
| AI/ML Lead | CREATE | New agent |
| DBA Lead | CREATE | New agent |

To update DevOps Lead: Paperclip dashboard → Company → Agents → DevOps →
Edit → update `instructionsFilePath` and `args` fields → Save. Agent picks
up changes on next heartbeat.
