# Home Office

Home Office keeps one person's events, tasks and todos. This file is a short
reference for a running instance: its settings, its commands and its MCP
endpoint. It is not about changing the code.

## Settings of the instance

Set in the environment of the running application. All are optional.

| Variable                         | Default                  | Meaning                                                                                                                                     |
| -------------------------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `HOME_OFFICE_ADMIN_PASSWORD`     | a hidden prompt          | Password for the first administrator in `home_office:setup`                                                                                 |
| `HOME_OFFICE_ALLOWED_ORIGINS`    | none                     | Addresses that browsers use to reach the application, separated by commas; needed when a proxy sends a different host, or live updates fail |
| `HOME_OFFICE_BACKUP_DIR`         | `storage/backups`        | Where the backups go                                                                                                                        |
| `HOME_OFFICE_BACKUP_KEEP`        | `14`                     | How many backups stay                                                                                                                       |
| `HOME_OFFICE_BACKUP_SCHEDULE`    | `every day at 3am`       | When the backup job runs; it does nothing on a day that already has a backup                                                                |
| `HOME_OFFICE_CATCH_UP`           | `lazy`                   | What makes the past events of series real: `lazy` (the requests of users), `job` (an hourly job) or `off`                                   |
| `HOME_OFFICE_CATCH_UP_SCHEDULE`  | `every hour at minute 5` | When that job runs                                                                                                                          |
| `HOME_OFFICE_ENABLE_HARD_DELETE` | off                      | `1` or `true` lets an administrator delete a deactivated user and all their data                                                            |
| `HOME_OFFICE_PURGE_SCHEDULE`     | `every hour`             | When things that have been in the trash too long are deleted for good                                                                       |
| `HOME_OFFICE_SCHEDULE_TIME_ZONE` | UTC                      | The time zone in which the schedules above are read, such as `Europe/Rome`                                                                  |
| `HOME_OFFICE_SSL`                | off                      | `1` or `true` when a proxy ends HTTPS in front of the application                                                                           |

`RAILS_MASTER_KEY` opens the credentials in production.
`SOLID_QUEUE_IN_PUMA=true` runs the background jobs inside the web process,
which a single-machine install needs.

## Commands

- First administrator: `bin/rails 'home_office:setup[you@example.com]'`
- Back up now (always writes a file): `bin/rails home_office:backup`
- With Kamal, `bin/kamal admin` and `bin/kamal backup` run those two on the
  server, if `config/deploy.yml` defines the aliases. Add `-d <destination>`
  when the file requires one.
- Restore: stop the application, copy a backup over
  `storage/production.sqlite3`, delete `storage/production.sqlite3-wal` and
  `-shm` if they exist, start the application.

## MCP

Agents reach the application through one MCP endpoint.

### The endpoint

- `POST /mcp` on the address of the application. JSON-RPC 2.0, answered with
  plain JSON. There are no sessions and no streams: every request stands alone.
  Any other method gets 405.
- Send `Authorization: Bearer <token>` and `Content-Type: application/json`. The
  body is one JSON object, at most 256 KB.
- Do not send an `Origin` header. A request whose `Origin` is not the address of
  the application is refused with 403, which keeps web pages from using a token.
- A missing, wrong or retired token gets 401. Too many requests get 429: wait a
  minute.

### Tokens

A person makes a token in the application under Settings, Access tokens. The
text starts with `ho_` and is shown once. A token belongs to its user and sees
only the things of that user.

- A **read-only** token gets the tools that read. A write token also gets the
  tools that change things.
- Deleting only moves things to the trash, from where they can be restored.
  Nothing you can do through MCP removes data for good.
- At most 120 requests a minute for each token. Requests with a token that the
  application does not know are counted by the address of the client.

### Tools

Ask `tools/list` for the arguments of each tool. What each one is for:

| Tool            | Kind  | Use it to                                                                                      |
| --------------- | ----- | ---------------------------------------------------------------------------------------------- |
| `overview`      | read  | Start here: today's date, the counts of the home page and short lists of what needs a look     |
| `list_items`    | read  | List events, tasks and todos; narrow by days, view (important, missed, forgotten) or the trash |
| `get_item`      | read  | Read one item whole: notes, series and links                                                   |
| `create_item`   | write | Create an event, task or todo; an event with `repeat` makes a series                           |
| `update_items`  | write | Change up to 50 items; each change succeeds or fails on its own                                |
| `trash_items`   | write | Move up to 50 items to the trash                                                               |
| `restore_items` | write | Take up to 50 items out of the trash                                                           |
| `link_items`    | write | Link up to 50 pairs of items                                                                   |
| `unlink_items`  | write | Remove the link between up to 50 pairs                                                         |

### How an item is named

An item is named by its id, such as `123`. One occurrence of a repeating event
is `s7@2026-11-03` (series 7, on that date), and a whole series is `s7`. Times
are local to the time zone of the user, and dates are ISO 8601 (`2026-11-03`).
