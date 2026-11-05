# Ensures that an invalid value for HOME_OFFICE_CATCH_UP so we get the error
# immediately at boot.
Rails.application.config.after_initialize { Core::CatchUpMode.mode }
