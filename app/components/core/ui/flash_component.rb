class Core::UI::FlashComponent < ApplicationComponent
  KINDS = {
    "notice" => {role: "status", css: "alert-soft alert-success", icon: "M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"},
    "alert" => {role: "alert", css: "alert-soft alert-error", icon: "M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z"}
  }.freeze

  def initialize(kind:, message:)
    @kind = kind.to_s
    @message = message
  end

  def render? = KINDS.key?(@kind) && @message.present?

  def config = KINDS.fetch(@kind)
end
