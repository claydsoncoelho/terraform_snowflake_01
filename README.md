# Snowflake Config Validator

A standalone Python tool that checks the YAML configuration files in `configs/` against
Snowflake and company best practices.

It is **informative, not blocking**. It never edits files, never talks to Snowflake, and
never prevents a deployment. It reads YAML, prints findings, and exits.

---

## Table of Contents

1. [Why this exists](#why-this-exists)
2. [How it fits with Terraform](#how-it-fits-with-terraform)
3. [Project layout](#project-layout)
4. [What each file does](#what-each-file-does)
5. [The sixteen config types](#the-sixteen-config-types)
6. [The environment model](#the-environment-model)
7. [Built-in objects](#built-in-objects)
8. [Anatomy of a rule](#anatomy-of-a-rule)
9. [Rule IDs](#rule-ids)
10. [Adding a new rule](#adding-a-new-rule)
11. [Waivers](#waivers)
12. [Severity and exit codes](#severity-and-exit-codes)
13. [Output](#output)
14. [Rules shipped in v1](#rules-shipped-in-v1)
15. [Requirements](#requirements)
16. [Decisions log](#decisions-log)
17. [Deliberately out of scope](#deliberately-out-of-scope)

---

## Why this exists

`terraform plan` tells you *what will be deployed*. It cannot tell you whether what you are
deploying is a good idea.

Terraform will happily create a user with no role attached, a database with no schemas, or an
account role that nobody can reach because it was never granted to `SYSADMIN`. Every one of
those is valid HCL and valid Snowflake — and every one of them is a mistake.

This validator is the checklist that catches them. The intended experience:

> Someone adds a new user to `users.yaml` six months from now, runs `make plan`, and sees:
>
> ```
> WARNING  users.must-have-role
>          Every user must be granted at least one role.
>
>   ANALYST_SVC_USER   is not assigned to any role
>                      configs/envs/common/governance_security/users.yaml
> ```

The value of this tool is the message, not the pass/fail. Every finding must name the
problem, name the file, and be understandable by someone who has never opened this codebase.

### Why not do this in Terraform?

Terraform's `check` blocks can produce warnings, and simple rules are expressible in HCL. But
the rules we actually need are not simple:

- **Transitive checks.** "Every role reaches `SYSADMIN`" is a graph reachability problem — a
  role may inherit through two or three intermediate roles. HCL has no recursion and no
  loops, so this cannot be written generically.
- **Useful messages.** `check` blocks emit one string per block. We want per-item findings
  that name the offending file.
- **Authoring cost.** Rules should be easy to write. HCL is not.

So the validator is plain Python, decoupled from Terraform entirely.

---

## How it fits with Terraform

The two programs know nothing about each other. A `Makefile` in the project root runs them in
sequence:

```make
plan:
	terraform plan
	python -m validator.main
```

```
make plan  →  terraform plan  →  validator  →  findings printed below the plan
```

You can also run the validator entirely on its own. It needs no credentials, no backend
access, and no working Terraform — which matters, because a broken `terraform plan` is
exactly when you most want fast feedback.

---

## Project layout

```
validator/
├── README.md            ← you are here
├── main.py              ← entry point: CLI args, orchestration
├── loader.py            ← reads YAML files off disk
├── model.py             ← the in-memory representation of all config
├── builtins.py          ← Snowflake system-provided object names
├── registry.py          ← the @rule decorator and rule auto-discovery
├── reporter.py          ← formats and prints findings
├── waivers.yaml         ← accepted exceptions
└── rules/
    ├── _helpers.py       ← shared logic, skipped by discovery
    ├── check_account_roles.py
    ├── check_users.py
    ├── check_databases.py
    ├── check_schemas.py
    ├── check_schema_grants.py
    ├── check_network_policies.py
    ├── check_uniqueness.py
    ├── check_config.py
    └── check_waivers.py
```

---

## What each file does

### `main.py` — entry point

Parses command-line arguments, calls the loader, asks the registry for all discovered rules,
runs each one, applies waivers, and hands the results to the reporter. Deliberately thin: it
orchestrates, it does not contain logic.

| Flag | Purpose |
| :--- | :--- |
| `--config-dir PATH` | Where `configs/` lives. Defaults to the repo root. |
| `--list-rules` | Print every registered rule and its description, then exit. |
| `--strict` | Treat findings as failures (exit non-zero). For CI. |
| `--rule ID` | Run only the named rule. Useful when developing one. |
| `--no-color` | Disable colour output. |

`--list-rules` matters more than it looks. Splitting rules across files means you lose the
ability to scroll one file and see everything; this flag gives that back.

### `loader.py` — reading the YAML

Finds and parses every YAML file under `configs/`. This file owns all the mess:

- The glob patterns, which must mirror the `fileset()` calls in `main.tf`
- Normalisation — `upper()` on names, so `dev_raw` and `DEV_RAW` compare equal
- Default values for optional fields
- Tolerating missing files
- **The declared field list for each config type**, which drives `config.unknown-field`

Every item it produces is tagged with two things beyond its own fields:

- **`source_file`** — the path it came from, so findings can point at it
- **`environment`** — `dev`, `test`, `prod`, or `common`

**The loader parses all sixteen config types from day one**, even those with no rules yet.
This is required for `config.no-orphan-files` and `config.unknown-field` to work, and it means
adding rules later touches only `rules/`.

#### Parsing quirks the loader must mirror exactly

| Type | Quirk |
| :--- | :--- |
| Schemas | **Grouped form** — a `database:` key with a nested `schemas:` list, not a flat list |
| Role hierarchy | Accepts **both** singular (`role`, `database_role`) and plural (`roles`, `database_roles`) |
| All names | Normalised to uppercase before comparison, matching `upper()` in `main.tf` |
| Common-only files | Missing file decodes to empty, not an error |

> ⚠️ **Glob drift.** The patterns here duplicate the ones in `main.tf`. If someone changes a
> path in Terraform and not here, the validator silently stops checking those files. The
> `config.no-orphan-files` rule exists to catch exactly this. Keep the Terraform globs listed
> in a comment block at the top of this file for side-by-side comparison.

### `model.py` — the in-memory representation

Defines the shape of the loaded data: what a Role is, what a User is, what a Schema is. One
collection per entity type.

Rules read the model and nothing else. They never touch the filesystem and never parse YAML.
This is what keeps each rule down to a handful of lines.

The model also carries derived structures that many rules need, built once at load time
rather than recomputed by every rule:

- **The role hierarchy as a graph**, so reachability questions are cheap. Needs a
  `reaches(child, ancestor)` method that walks transitively and is cycle-safe.
- **Lookup maps by name**, so "does this role exist?" is not a linear scan.

### `builtins.py` — Snowflake system objects

See [Built-in objects](#built-in-objects). Kept separate from rule code so it can be edited
as Snowflake adds system roles, without touching any logic.

### `registry.py` — discovery and registration

Two jobs:

1. Provide the `@rule(...)` decorator that rule functions use to declare themselves.
2. Scan the `rules/` folder at startup, import every module, and collect what registered.

The point of auto-discovery is that **adding a rule requires no central file edit**. Drop a
file in `rules/`, and it runs. If `main.py` had to import each rule by hand, splitting the
files would have solved nothing — you would just have moved the bottleneck.

Three safety requirements:

- **Crash on import errors.** A syntax error in one rule file must be loud. The failure mode
  of auto-discovery is silence — a rule that quietly never runs is worse than no rule.
- **Reject duplicate rule IDs at startup**, before anything runs.
- **Isolate rule execution.** A rule that raises at runtime is caught, reported as an `ERROR`
  attributed to that rule, and the run continues. One broken rule must not hide the findings
  of the other seventeen.

Files starting with `_` are skipped, which is why shared logic lives in `_helpers.py`.

### `reporter.py` — output

Turns findings into terminal output: grouping, severity labels, colour, and the summary line.
Isolated here so that adding JSON or SARIF output later is a new function, not a rewrite. See
[Output](#output).

### `rules/` — the checks

One file per **domain**, not per rule. `check_users.py` holds every user-related rule.

This is the unit that scales. One file per rule would give us a hundred files of identical
import boilerplate. One file for everything gives us a 3,000-line file and a merge conflict
every time two people add a rule in the same week. Domain files land in between: roughly a
dozen files, each obviously named, each short enough to read in full.

`_helpers.py` holds logic shared across domains. The most important is **reference
resolution** — see [The environment model](#the-environment-model).

---

## The sixteen config types

The loader must discover all sixteen. They come in two shapes, and the difference matters.

### Common-only (6)

Hardcoded paths guarded by `fileexists()`. Environment is always `common`. A missing file
decodes to empty rather than failing.

| Type | Path |
| :--- | :--- |
| Permission Sets | `configs/envs/common/governance_security/permission_sets.yaml` |
| Account Parameters | `configs/envs/common/governance_security/account_parameter.yaml` |
| Network Rules | `configs/envs/common/governance_security/network_rules.yaml` |
| Network Policies | `configs/envs/common/governance_security/network_policies.yaml` |
| Users | `configs/envs/common/governance_security/users.yaml` |
| User Role Assignments | `configs/envs/common/governance_security/user_role_assignments.yaml` |

### Glob-based (10)

Discovered by `fileset()`. Environment comes from path segment 2, mirroring
`split("/", filename)[2]` in `main.tf`. An unmatched glob yields nothing, so no guard is
needed.

| Type | Path |
| :--- | :--- |
| Account Roles | `configs/envs/*/governance_security/roles/*.yaml` |
| Databases | `configs/envs/*/catalog/databases/*.yaml` |
| Schemas | `configs/envs/*/catalog/schemas/*.yaml` |
| Role Hierarchy | `configs/envs/*/governance_security/role_hierarchy.yaml` |
| Database Grants | `configs/envs/*/governance_security/database_grants/*.yaml` |
| Schema Grants | `configs/envs/*/governance_security/schema_grants/*.yaml` |
| Ownerships | `configs/envs/*/governance_security/ownerships.yaml` |
| Warehouses | `configs/envs/*/compute/warehouses/*.yaml` |
| Warehouse Grants | `configs/envs/*/governance_security/warehouse_grants/*.yaml` |
| Resource Monitors | `configs/envs/*/admin/resource_monitors/*.yaml` |

---

## The environment model

The validator runs **globally**: it loads every environment plus `common` in a single pass and
validates them together. This is what makes cross-environment rules possible.

Environment is derived from the **folder path**, never from the object's name.
`configs/envs/dev/...` is `dev`, regardless of what the resources inside are called.

### The governing principle

> **Environment folders are sealed. `common` is universal.**

A file in `configs/envs/dev/` may only name objects defined in `dev` or in `common`. A file in
`common/` may name anything.

| Relationship | Rule |
| :--- | :--- |
| Schema → Database | Same environment, or database is in `common` |
| User → Role | Any environment (users live in `common`, which is universal) |
| Role hierarchy entries | Sealed — a `dev` role may not appear in `prod`'s hierarchy |
| Warehouse grants | Sealed |
| Database and schema grants | Sealed |
| Network rule → its host database/schema | **Allowed anywhere.** See below. |

Checking against the **file's** environment rather than comparing the two referenced objects
to each other is the stronger version: it also catches an internally-consistent `prod` grant
that is sitting in the `dev` folder by mistake.

### Reference resolution

Non-existence and cross-environment violations are two outcomes of the same lookup, so
`_helpers.py` implements one resolver used by every reference rule:

1. Is the name a [built-in](#built-in-objects)? → OK.
2. Does the name exist in the referencing file's own environment, or in `common`? → OK.
3. Does it exist, but in a different environment? → **cross-environment** finding.
4. Does it not exist at all? → **does not exist** finding.

Each reference relationship gets **one rule ID** covering both failure modes, with the message
distinguishing them. This keeps waivers simple — one object, one rule, one waiver.

### Network rules are references, not creations

`network_rules.yaml` lives in `common/` but names a `database` and `schema` to store the rule
object in. That is `common` pointing into an environment, which is the schema→database
relationship running the other way.

Treat it as a **reference**, not a creation: `common` may point anywhere, so this is allowed.
The alternative — requiring network rules to live in the environment of their host database —
contradicts the current folder layout.

### Global uniqueness

Sealed folders catch a mistaken *reference*. They do not catch a mistaken *definition*.

The scenario: someone copies `dev/` to `test/` and forgets to rename an object. `DEV_RAW` is
now defined in both folders. Environment comes from the path, so the copy registers as a
legitimate `test` object, and everything referencing it inside `test/` is internally
consistent. Every rule passes.

Except Snowflake has **one global namespace**. The second `terraform apply` collides with the
first.

So: account-level objects — databases, account roles, warehouses, users, resource monitors,
network policies — must be **uniquely named across all environments**. A duplicate is an
`ERROR`. Schemas are the exception: they are unique per database, so the uniqueness key is
`DATABASE.SCHEMA`.

This closes the copy-paste failure from both directions.

---

## Built-in objects

Snowflake provides objects that appear in configuration but are defined in no YAML file:

- Account roles: `ACCOUNTADMIN`, `SECURITYADMIN`, `USERADMIN`, `SYSADMIN`, `ORGADMIN`,
  `PUBLIC`
- The `SNOWFLAKE` database and its database roles (`USAGE_VIEWER`, `DATA_METRIC_USER`,
  `OBJECT_VIEWER`, and others)

Without this registry, the sealed-folder rule and every referential-integrity rule would flag
`SYSADMIN` on the very first run. A tool that cries wolf in its first five minutes gets
ignored forever.

Builtins **always resolve** and **belong to no environment**, so they are exempt from both
existence and sealing checks. Snowflake adds database roles over time, so `builtins.py` must
be editable without touching rule code.

---

## Anatomy of a rule

Every rule is a function that takes the model and produces findings. Auto-discovery only works
if they are all identical from the outside.

```python
@rule(
    id="roles.must-inherit-sysadmin",
    severity=Severity.WARNING,
    description="Every custom account role must be reachable from SYSADMIN.",
)
def check_roles_reach_sysadmin(model):
    for role in model.roles:
        if not model.role_graph.reaches(role.name, "SYSADMIN"):
            yield Finding(
                object_name=role.name,
                message=f"Role '{role.name}' is not granted to SYSADMIN, directly or indirectly.",
                source_file=role.source_file,
            )
```

### The Finding

```python
@dataclass
class Finding:
    object_name: str            # "DEV_REPORTING_ROLE" — machine-readable key
    message: str                # human-readable sentence
    source_file: str            # path the problem came from
    severity: Severity = None   # optional per-finding override
```

### Contract details

- **Findings do not carry the rule ID or severity.** The runner stamps both from the
  decorator. Repeating them in each finding means typing them twice, and they will drift.
- **`object_name` is its own field**, not buried in the message. Waivers key on it, and the
  reporter sorts by it. Waivers matching against prose would be fragile.
- **`yield` and `return` both work.** The runner wraps the call in `list(...)`. Yielding per
  violation is nicer to write — no accumulator variable.
- **The signature is `(model)` and nothing else.** Waivers are applied by the runner *after*
  the rule returns, so rules stay ignorant of them, five lines long, and independently
  testable.
- **Provenance is file-level.** Findings name the file, not the line. Line numbers would
  require a custom YAML loader that preserves node positions; `file + object_name` is enough
  to locate anything. Deferred, not free later — noted so nobody assumes otherwise.

---

## Rule IDs

Format: `domain.kebab-case-description`

```
roles.must-inherit-sysadmin
users.must-have-role
users.network-policy-must-exist
databases.must-have-schema
schemas.database-must-exist
config.unknown-field
```

The ID appears in every finding, in `--list-rules`, and is the key for waivers. Renaming one
later breaks anyone who has waived it, so pick carefully the first time.

---

## Adding a new rule

1. Pick the domain file in `rules/`, or create a new `check_<domain>.py` if none fits.
2. Write a function decorated with `@rule(...)`, giving it an ID, a severity, and a
   description.
3. Read what you need from the model. Yield a `Finding` for each violation, naming the object
   and its source file.
4. Run `python -m validator.main --rule your.rule-id` to test it in isolation.
5. Run `--list-rules` to confirm it registered.

No other file needs to change.

---

## Waivers

A waiver says: **"I know. It's intentional. Stop telling me."**

The case it exists for: someone creates `AUDIT_ROLE` and deliberately does *not* grant it to
`SYSADMIN`, because the point is that SYSADMIN cannot inherit the auditor's access. That is
correct security design, but the validator does not know it — and would flag it on every run,
forever.

Without waivers, the options are to live with permanent noise (and everyone starts ignoring
the output, including the real findings) or to delete the rule (losing the check for all fifty
other roles). Neither is acceptable.

`validator/waivers.yaml`:

```yaml
- rule: roles.must-inherit-sysadmin
  object: AUDIT_ROLE
  reason: "Deliberately isolated from SYSADMIN for audit segregation."
  expires: 2027-01-01   # optional
```

| Field | Required | Purpose |
| :--- | :---: | :--- |
| `rule` | Yes | Rule ID to suppress |
| `object` | Yes | Matches `Finding.object_name` exactly |
| `reason` | Yes | Why this is acceptable. The most valuable field here. |
| `expires` | No | Date after which the waiver stops working |

**A waiver silences only that exact pairing.** If `AUDIT_ROLE` later breaks a different rule,
you still get told.

Two self-maintaining behaviours:

- **An expired waiver is itself a finding** (`waivers.expired`, `WARNING`). Without this,
  "temporary" exceptions become permanent by default.
- **An unused waiver reports as `INFO`** (`waivers.unused`). If the underlying problem was
  fixed, the waiver is dead weight — saying so keeps `waivers.yaml` from becoming a graveyard
  nobody dares to prune.

**The honest downside:** this is a bypass mechanism. Someone can waive a real problem instead
of fixing it. The mandatory `reason` and the fact that waivers are visible in code review are
the mitigation. It is a trust tool, not an enforcement one.

The file lives in `validator/`, not `configs/`, because it is validator configuration rather
than Snowflake configuration — and because `config.no-orphan-files` walks `configs/` and would
otherwise flag it.

---

## Severity and exit codes

| Severity | Meaning |
| :--- | :--- |
| `ERROR` | References something that does not exist, **or deploys something demonstrably wrong.** |
| `WARNING` | Violates best practice. Deployment will still work. |
| `INFO` | Advisory. Worth knowing, not worth acting on today. |

Cross-environment violations and global name collisions are `ERROR`. They deploy without
complaint but put objects in the wrong place, which is what the second clause is for.
Legitimate exceptions go through waivers rather than being pre-emptively softened into noise.

### Exit codes

| Situation | Default | `--strict` |
| :--- | :---: | :---: |
| No findings | 0 | 0 |
| Findings of any severity | **0** | **non-zero** |
| A rule crashed | **non-zero** | non-zero |

Findings never block a local run: the validator is informative by design. A rule *crashing* is
different — that is the validator being broken, not your config, and it must be impossible to
ignore. It cannot block `terraform apply` anyway, since it runs afterwards.

`--strict` is what CI uses on pull requests, so the same tool serves both a gentle local
reminder and a hard gate on merge.

---

## Output

Findings are **grouped by rule, ordered by severity** — all `ERROR` rules first, then
`WARNING`, then `INFO`.

Grouping by rule rather than by file means the explanation is read once and every affected
object appears beneath it, which is how you actually want to work through a checklist.

Traffic-light colours: **red** for `ERROR`, **amber** for `WARNING`, **green** for `INFO` and
for the all-clear. Colour is disabled automatically when output is piped or redirected, and by
`--no-color`.

```
ERROR  schemas.database-must-be-same-environment
       A schema must live in a database of its own environment.

  TEST_ANALYTICS.MARTS   database 'DEV_ANALYTICS' belongs to environment 'dev'
                         configs/envs/test/catalog/schemas/analytics.yaml

WARNING  users.must-have-role
         Every user must be granted at least one role.

  ANALYST_SVC_USER   is not assigned to any role
                     configs/envs/common/governance_security/users.yaml

──────────────────────────────────────────────────────
1 error, 1 warning, 0 info   (2 rules with findings, 16 passed)
```

---

## Rules shipped in v1

The loader parses everything; rules cover the domains identified so far. Everything else is a
later addition to `rules/` alone.

| File | Rule ID | Severity |
| :--- | :--- | :---: |
| `check_account_roles.py` | `roles.must-inherit-sysadmin` | WARNING |
| `check_users.py` | `users.must-have-role` | WARNING |
| | `users.role-must-exist` | ERROR |
| | `users.must-have-network-policy` | WARNING |
| | `users.network-policy-must-exist` | ERROR |
| | `users.default-role-must-exist` | ERROR |
| | `users.default-warehouse-must-exist` | ERROR |
| `check_databases.py` | `databases.must-have-schema` | WARNING |
| `check_schemas.py` | `schemas.database-must-exist` | ERROR |
| | `schemas.database-must-be-same-environment` | ERROR |
| `check_schema_grants.py` | `schema-grants.permission-set-must-exist` | ERROR |
| `check_network_policies.py` | `network-policies.rule-must-exist` | ERROR |
| | `network-rules.schema-must-exist` | ERROR |
| `check_uniqueness.py` | `uniqueness.account-objects-must-be-unique` | ERROR |
| `check_config.py` | `config.no-orphan-files` | WARNING |
| | `config.unknown-field` | WARNING |
| `check_waivers.py` | `waivers.expired` | WARNING |
| | `waivers.unused` | INFO |

### Two rules worth explaining

**`schema-grants.permission-set-must-exist`.** `main.tf` reads
`local.permission_sets[g.permission_set]` with square-bracket indexing. A typo in a permission
set name aborts the plan with `Invalid index: The given key does not identify an element in
this collection value` — and names neither the file nor the grant. Failing hard is the correct
Terraform behaviour (a silent default would deploy a grant with zero privileges), so the fix
belongs here: catch the typo first, with a message that says where it is.

**`config.unknown-field`.** A YAML key that Terraform silently drops is invisible until
something doesn't work in Snowflake. This was not hypothetical — `is_transient` was documented
in the Terraform README, used in both of its examples, and never read by `flat_databases`.
Anyone setting it got a permanent database and no error anywhere. Finding it required a manual
line-by-line comparison of the README against `main.tf`.

The cost is that `loader.py` must declare which fields each of the sixteen types consumes.
That declaration is not wasted work: it is the schema the rest of the validator reads against,
and it doubles as executable documentation of the YAML contract.

---

## Requirements

- **Python 3.10+**
- **PyYAML** — the only third-party dependency. Everything else is standard library.

---

## Decisions log

Why things are the way they are, so they are not re-litigated in six months.

| Decision | Rationale |
| :--- | :--- |
| Python, not Terraform `check` blocks | Transitive role reachability is impossible in HCL; messages are better |
| Validator does not invoke `terraform` | Keeps it credential-free, fast, and usable when `terraform plan` is broken |
| Global run, all environments at once | Required for cross-environment and uniqueness rules |
| Environment from folder path, not name | Naming conventions vary per client; the path is unambiguous |
| Sealed folders, universal `common` | One principle covering every cross-environment relationship |
| Global uniqueness rule | Sealing catches bad references; only uniqueness catches a duplicated *definition* |
| No naming-convention rule | Client-specific (`PRD` vs `PROD`, prefix vs suffix). A rabbit hole with no correct default. |
| Domain files, not one file per rule | 12 navigable files instead of 100 boilerplate ones or one 3,000-line file |
| Auto-discovery | Adding a rule must not require editing a central file |
| Waivers in v1 | Without them, the first legitimate exception gets "fixed" by commenting out the rule |
| Findings exit 0 by default | Informative tool. `--strict` exists for CI. |
| Loader uppercases everywhere | `main.tf` now normalises consistently, so mirroring it is straightforward |
| `permission_sets` left as a hard index in `main.tf` | Crashing on a typo is correct; a silent default would deploy an empty grant |
| `config.unknown-field` included in v1 | The `is_transient` bug was exactly this class and took a manual audit to find |

---

## Deliberately out of scope

- **Line-level provenance.** File plus object name locates anything. Revisit only if findings
  prove hard to track down in practice — and note it means replacing the YAML loader.
- **Naming-convention rules.** See above.
- **Validating `terraform show -json` instead of the YAML.** It would catch bugs in `main.tf`'s
  own parsing, which YAML-level validation cannot — but it needs credentials, a full plan, and
  produces worse messages. Every rule identified so far is answerable from YAML alone.
- **Anything that writes.** The validator never modifies configuration, and never will.
  Auto-fixing is a different tool with different risks.