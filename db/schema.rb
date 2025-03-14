# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2025_03_10_094932) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "blocks", force: :cascade do |t|
    t.string "block_hash"
    t.integer "height", null: false
    t.integer "timestamp"
    t.string "work"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "parent_id"
    t.integer "mediantime"
    t.integer "first_seen_by_id"
    t.integer "version"
    t.string "pool"
    t.integer "tx_count"
    t.integer "size"
    t.boolean "connected", default: false
    t.integer "marked_invalid_by", default: [], array: true
    t.integer "marked_valid_by", default: [], array: true
    t.string "coinbase_message"
    t.boolean "pruned"
    t.boolean "headers_only", default: false, null: false
    t.decimal "total_fee", precision: 16, scale: 8
    t.index ["block_hash"], name: "index_blocks_on_block_hash", unique: true
    t.index ["first_seen_by_id"], name: "index_blocks_on_first_seen_by_id"
    t.index ["height"], name: "index_blocks_on_height"
    t.index ["parent_id"], name: "index_blocks_on_parent_id"
    t.index ["work"], name: "index_blocks_on_work"
  end

  create_table "chaintips", force: :cascade do |t|
    t.bigint "node_id"
    t.bigint "block_id"
    t.bigint "parent_chaintip_id"
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["block_id"], name: "index_chaintips_on_block_id"
    t.index ["node_id"], name: "index_chaintips_on_node_id"
    t.index ["parent_chaintip_id"], name: "index_chaintips_on_parent_chaintip_id"
  end

  create_table "inflated_blocks", force: :cascade do |t|
    t.bigint "block_id"
    t.decimal "max_inflation", precision: 16, scale: 8
    t.decimal "actual_inflation", precision: 16, scale: 8
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "node_id"
    t.datetime "dismissed_at"
    t.index ["block_id"], name: "index_inflated_blocks_on_block_id"
    t.index ["node_id"], name: "index_inflated_blocks_on_node_id"
  end

  create_table "invalid_blocks", force: :cascade do |t|
    t.integer "block_id"
    t.integer "node_id"
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "dismissed_at"
    t.index ["block_id"], name: "index_invalid_blocks_on_block_id"
    t.index ["node_id"], name: "index_invalid_blocks_on_node_id"
  end

  create_table "jwt_blacklist", force: :cascade do |t|
    t.string "jti", null: false
    t.index ["jti"], name: "index_jwt_blacklist_on_jti"
  end

  create_table "lags", force: :cascade do |t|
    t.integer "node_a_id"
    t.integer "node_b_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "notified_at"
    t.boolean "publish", default: true, null: false
    t.integer "blocks", default: 0
    t.index ["node_a_id"], name: "index_lags_on_node_a_id"
    t.index ["node_b_id"], name: "index_lags_on_node_b_id"
  end

  create_table "nodes", force: :cascade do |t|
    t.string "name"
    t.integer "version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "unreachable_since"
    t.string "rpchost"
    t.string "rpcuser"
    t.string "rpcpassword"
    t.boolean "ibd"
    t.integer "peer_count"
    t.integer "client_type"
    t.integer "rpcport"
    t.integer "block_id"
    t.string "version_extra", default: "", null: false
    t.boolean "pruned", default: false, null: false
    t.string "os"
    t.string "cpu"
    t.integer "ram"
    t.string "storage"
    t.boolean "cve_2018_17144", default: false, null: false
    t.date "released"
    t.boolean "enabled", default: true, null: false
    t.string "mirror_rpchost"
    t.integer "mirror_rpcport"
    t.bigint "mirror_block_id"
    t.boolean "txindex", default: false, null: false
    t.datetime "mirror_rest_until"
    t.boolean "python", default: false, null: false
    t.datetime "polled_at"
    t.integer "sync_height"
    t.datetime "mirror_unreachable_since"
    t.datetime "last_polled_mirror_at"
    t.string "link"
    t.string "link_text"
    t.integer "mempool_count"
    t.integer "mempool_bytes"
    t.integer "mempool_max"
    t.boolean "mirror_ibd", default: false, null: false
    t.boolean "to_destroy", default: false, null: false
    t.boolean "coinstatsindex"
    t.boolean "checkpoints", default: true, null: false
    t.index ["block_id"], name: "index_nodes_on_block_id"
    t.index ["mirror_block_id"], name: "index_nodes_on_mirror_block_id"
  end

  create_table "pools", force: :cascade do |t|
    t.string "tag"
    t.string "name"
    t.string "url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["tag"], name: "index_pools_on_tag"
  end

  create_table "softforks", force: :cascade do |t|
    t.bigint "node_id"
    t.integer "fork_type"
    t.string "name"
    t.integer "bit"
    t.integer "status"
    t.integer "since"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "notified_at"
    t.index ["node_id"], name: "index_softforks_on_node_id"
  end

  create_table "stale_candidate_children", force: :cascade do |t|
    t.bigint "stale_candidate_id"
    t.bigint "root_id"
    t.bigint "tip_id"
    t.integer "length"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["root_id"], name: "index_stale_candidate_children_on_root_id"
    t.index ["stale_candidate_id"], name: "index_stale_candidate_children_on_stale_candidate_id"
    t.index ["tip_id"], name: "index_stale_candidate_children_on_tip_id"
  end

  create_table "stale_candidates", force: :cascade do |t|
    t.integer "height"
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "confirmed_in_one_branch", default: [], null: false, array: true
    t.decimal "confirmed_in_one_branch_total", precision: 16, scale: 8
    t.string "double_spent_in_one_branch", default: [], null: false, array: true
    t.decimal "double_spent_in_one_branch_total", precision: 16, scale: 8
    t.integer "n_children"
    t.string "rbf", default: [], null: false, array: true
    t.decimal "rbf_total", precision: 16, scale: 8
    t.integer "height_processed"
    t.string "double_spent_by", default: [], null: false, array: true
    t.string "rbf_by", default: [], null: false, array: true
    t.boolean "missing_transactions", default: false, null: false
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "endpoint"
    t.string "p256dh"
    t.string "auth"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "block_id"
    t.string "tx_id", limit: 64, null: false
    t.boolean "is_coinbase", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "amount", precision: 16, scale: 8, null: false
    t.binary "raw", null: false
    t.index ["block_id"], name: "index_transactions_on_block_id"
    t.index ["is_coinbase"], name: "index_transactions_on_is_coinbase"
    t.index ["tx_id"], name: "index_transactions_on_tx_id"
  end

  create_table "tx_outsets", force: :cascade do |t|
    t.integer "block_id"
    t.integer "txouts"
    t.decimal "total_amount", precision: 16, scale: 8
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "node_id"
    t.boolean "inflated", default: false, null: false
    t.index ["block_id"], name: "index_tx_outsets_on_block_id"
    t.index ["node_id"], name: "index_tx_outsets_on_node_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "version_bits", force: :cascade do |t|
    t.integer "bit"
    t.integer "activate_block_id"
    t.integer "deactivate_block_id"
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activate_block_id"], name: "index_version_bits_on_activate_block_id"
    t.index ["deactivate_block_id"], name: "index_version_bits_on_deactivate_block_id"
  end

  add_foreign_key "chaintips", "blocks"
  add_foreign_key "chaintips", "chaintips", column: "parent_chaintip_id"
  add_foreign_key "chaintips", "nodes"
  add_foreign_key "inflated_blocks", "blocks"
  add_foreign_key "inflated_blocks", "nodes"
  add_foreign_key "stale_candidate_children", "blocks", column: "root_id"
  add_foreign_key "stale_candidate_children", "blocks", column: "tip_id"
  add_foreign_key "stale_candidate_children", "stale_candidates"
  add_foreign_key "transactions", "blocks"
  add_foreign_key "tx_outsets", "nodes"
end
