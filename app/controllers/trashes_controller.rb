# Where to look in the trash.
#
# One card for each module that keeps one, with what is in it.
class TrashesController < ApplicationController
  def show
    @sources = Core::Modules.trash_sources
  end
end
