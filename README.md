# Home Office

A Ruby on Rails application to organize your time: events, tasks and todos,
with calendar, schedule and agenda views, links between records, repeating
events, and a dashboard as home page where you can see the status of those at a
glance.

The interface is in English and Italian, with a light and a dark theme. An MCP
endpoint lets AI agents read and change your schedule.

Built with Ruby on Rails 8.1, SQLite, Hotwire, Tailwind and daisyUI. No Node.

## Run it locally

You need Ruby 4.0.5 (`mise install` reads the version from `mise.toml`) and
Chrome or Chromium with its driver for the system tests.

```bash
bin/setup
```

It installs the gems, prepares the databases and starts the development server
at <http://localhost:3000>.

Run `bin/setup --skip-server` to skip the server,
and `bin/dev` to start it later.

In development the seeds create `demo-admin@example.com` and
`demo-user@example.com`, both with the password `development-only-password`.
They exist only in development.

`bin/ci` runs every check: security audits, linters, the tests, the system
tests with an accessibility scan, and the seeds.

## Deploy it

The `Dockerfile` builds the production image. Both options below need
`config/master.key`, which is not in the repository: see the end of this
section.

The settings that the application reads from the environment are listed below.

### Docker Compose

`compose.yaml` runs the image on one machine, with its data in a volume:

```bash
export RAILS_MASTER_KEY=$(cat config/master.key)
docker compose up --build -d
docker compose exec app bin/rails home_office:setup
```

The last command creates the first administrator. The application listens on
port 3000.

### Kamal

`config/deploy.yml` deploys the image with [Kamal](https://kamal-deploy.org).
It holds placeholders only: put the values of your server in
`config/deploy.production.yml` and `.kamal/secrets.production`, which git
ignores, then run:

```bash
bin/kamal setup -d production
bin/kamal admin -d production
```

The first command prepares the server and deploys, the second creates the first
administrator. `bin/kamal deploy -d production` deploys a new version.

### The master key

`config/master.key` opens `config/credentials.yml.enc`. It is not in the
repository, so a fresh clone does not have it. It needs none to run locally in
development or to test. A production deployment does.

To make a new one, delete `config/credentials.yml.enc` and run
`bin/rails credentials:edit`: Rails writes a new key and a new credentials
file, and opens it in your editor (`EDITOR`); save and close. Sessions end with
the old key, and nothing else is lost, because the application keeps nothing in
its credentials.

Keep a copy of the key outside the project, such as in a password manager.

## Settings

Set in the environment of the running application. All are optional.

| Variable                         | Default                  | Meaning                                                                                                                                                                                                                             |
| -------------------------------- | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `HOME_OFFICE_ADMIN_PASSWORD`     | a hidden prompt          | Password for the first administrator in `home_office:setup`                                                                                                                                                                         |
| `HOME_OFFICE_ALLOWED_ORIGINS`    | none                     | Addresses that browsers use to reach the application, separated by commas, such as `https://home-office.example.com:8081`. Needed for live updates when a proxy passes the application a different host from the one in the browser |
| `HOME_OFFICE_BACKUP_DIR`         | `storage/backups`        | Where the backups go                                                                                                                                                                                                                |
| `HOME_OFFICE_BACKUP_KEEP`        | `14`                     | How many backups stay                                                                                                                                                                                                               |
| `HOME_OFFICE_BACKUP_SCHEDULE`    | `every day at 3am`       | When the backup job runs                                                                                                                                                                                                            |
| `HOME_OFFICE_CATCH_UP`           | `lazy`                   | What saves the past occurrences of repeating events: `lazy` (on every user request), `job` (an hourly job) or `off` _(1)_                                                                                                           |
| `HOME_OFFICE_CATCH_UP_SCHEDULE`  | `every hour at minute 5` | If `HOME_OFFICE_CATCH_UP` is set to `job`, this is the schedule used                                                                                                                                                                |
| `HOME_OFFICE_ENABLE_HARD_DELETE` | off                      | `1` or `true` lets an administrator delete a deactivated user and all their data                                                                                                                                                    |
| `HOME_OFFICE_PURGE_SCHEDULE`     | `every hour`             | When things that have been in the trash too long are deleted for good                                                                                                                                                               |
| `HOME_OFFICE_SCHEDULE_TIME_ZONE` | UTC                      | The time zone in which the schedules above are read, such as `Europe/Rome`                                                                                                                                                          |
| `HOME_OFFICE_SSL`                | off                      | `1` or `true` when a proxy ends HTTPS in front of the application                                                                                                                                                                   |

**1:** A repeating event is stored as a rule, and its occurrences exist only as
computed dates. Once the day of an occurrence has passed, it is saved as an
event of its own, so that it can be ticked or shown as missed. The setting
chooses what does the saving: the requests of signed-in users, an hourly job, or
nothing. The "Missed events" page always does it when you open it.

`RAILS_MASTER_KEY` opens the credentials in production.
`SOLID_QUEUE_IN_PUMA=true` runs the background jobs inside the web process,
which a single-machine install needs.

## Commands

- First administrator: `bin/rails 'home_office:setup[you@example.com]'`
- Back up now (always writes a file): `bin/rails home_office:backup`
- With Kamal, `bin/kamal admin` and `bin/kamal backup` run those two on the
  server, if `config/deploy.yml` defines the aliases. Add `-d <destination>` when
  the file requires one.
- Restore: stop the application, copy a backup over
  `storage/production.sqlite3`, delete `storage/production.sqlite3-wal` and
  `-shm` if they exist, start the application.

## Agents

In the application make a token under Settings, Access tokens, and point an
MCP client at `POST /mcp` with it. `AGENTS.md` describes the endpoint and says
what each tool does.

## Contributing

This is a personal project. Feel free to fork it, or to open an issue if you
find a problem.

## License

MIT. See `LICENSE`.
