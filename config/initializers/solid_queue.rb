# Enqueues the catch-up once when the scheduler of the job queue starts, in
# `job` mode.
#
# Solid Queue does not run a scheduled job that was due while the application
# was stopped, so a computer that was off at the scheduled time catches up here
# instead, when it starts again.
SolidQueue.on_scheduler_start do
  Core::CatchUpJob.perform_later if Core::CatchUpMode.job?
end
