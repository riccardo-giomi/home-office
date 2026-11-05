class CreateCoreMcpTokens < ActiveRecord::Migration[8.1]
  def change
    # Only the SHA-256 of the token is kept (64 lowercase hex characters); the token itself is shown once
    create_table :core_mcp_tokens do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}, index: false
      t.string :name, null: false
      t.string :token_digest, null: false
      # A setting, so 0/1: a read-only token never reaches a tool that changes anything
      t.integer :read_only, null: false, default: 0
      t.datetime :last_used_at
      t.datetime :created_at, null: false

      t.check_constraint "read_only IN (0, 1)", name: "chk_core_mcp_tokens_read_only"
      t.check_constraint "length(token_digest) = 64 AND token_digest NOT GLOB '*[^0-9a-f]*'", name: "chk_core_mcp_tokens_digest"
    end
    add_index :core_mcp_tokens, :token_digest, unique: true
    add_index :core_mcp_tokens, [:user_id, :name], unique: true
  end
end
