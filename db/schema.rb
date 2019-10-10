# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_10_10_121441) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "blocks", force: :cascade do |t|
    t.string "block_hash"
    t.integer "height"
    t.integer "timestamp"
    t.string "work"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_id"
    t.integer "mediantime"
    t.bigint "first_seen_by_id"
    t.integer "version"
    t.integer "coin"
    t.string "pool"
    t.integer "tx_count"
    t.integer "size"
    t.index ["block_hash"], name: "index_blocks_on_block_hash", unique: true
    t.index ["coin"], name: "index_blocks_on_coin"
    t.index ["first_seen_by_id"], name: "index_blocks_on_first_seen_by_id"
    t.index ["parent_id"], name: "index_blocks_on_parent_id"
  end

  create_table "chaintips", force: :cascade do |t|
    t.bigint "node_id"
    t.bigint "block_id"
    t.bigint "parent_chaintip_id"
    t.integer "coin", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["block_id"], name: "index_chaintips_on_block_id"
    t.index ["node_id"], name: "index_chaintips_on_node_id"
    t.index ["parent_chaintip_id"], name: "index_chaintips_on_parent_chaintip_id"
  end

  create_table "inflated_blocks", force: :cascade do |t|
    t.bigint "block_id"
    t.bigint "comparison_block_id"
    t.decimal "max_inflation", precision: 16, scale: 8
    t.decimal "actual_inflation", precision: 16, scale: 8
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "node_id"
    t.datetime "dismissed_at"
    t.index ["block_id"], name: "index_inflated_blocks_on_block_id"
    t.index ["comparison_block_id"], name: "index_inflated_blocks_on_comparison_block_id"
    t.index ["node_id"], name: "index_inflated_blocks_on_node_id"
  end

  create_table "invalid_blocks", force: :cascade do |t|
    t.bigint "block_id"
    t.bigint "node_id"
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
    t.bigint "node_a_id"
    t.bigint "node_b_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "notified_at"
    t.index ["node_a_id"], name: "index_lags_on_node_a_id"
    t.index ["node_b_id"], name: "index_lags_on_node_b_id"
  end

  create_table "nodes", force: :cascade do |t|
    t.string "name"
    t.integer "version"
    t.bigint "block_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "unreachable_since"
    t.string "coin"
    t.string "rpchost"
    t.string "rpcuser"
    t.string "rpcpassword"
    t.boolean "ibd"
    t.integer "peer_count"
    t.integer "client"
    t.integer "client_type"
    t.integer "rpcport"
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
    t.index ["block_id"], name: "index_nodes_on_block_id"
    t.index ["mirror_block_id"], name: "index_nodes_on_mirror_block_id"
  end

  create_table "stale_candidates", force: :cascade do |t|
    t.integer "height"
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "coin"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "endpoint"
    t.string "p256dh"
    t.string "auth"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tx_outsets", force: :cascade do |t|
    t.bigint "block_id"
    t.integer "txouts"
    t.decimal "total_amount", precision: 16, scale: 8
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "node_id"
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
    t.bigint "activate_block_id"
    t.bigint "deactivate_block_id"
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activate_block_id"], name: "index_version_bits_on_activate_block_id"
    t.index ["deactivate_block_id"], name: "index_version_bits_on_deactivate_block_id"
  end

  add_foreign_key "blocks", "nodes", column: "first_seen_by_id"
  add_foreign_key "chaintips", "blocks"
  add_foreign_key "chaintips", "chaintips", column: "parent_chaintip_id"
  add_foreign_key "chaintips", "nodes"
  add_foreign_key "inflated_blocks", "blocks"
  add_foreign_key "inflated_blocks", "blocks", column: "comparison_block_id"
  add_foreign_key "inflated_blocks", "nodes"
  add_foreign_key "invalid_blocks", "blocks"
  add_foreign_key "invalid_blocks", "nodes"
  add_foreign_key "nodes", "blocks"
  add_foreign_key "tx_outsets", "blocks"
  add_foreign_key "tx_outsets", "nodes"
  add_foreign_key "version_bits", "blocks", column: "activate_block_id"
  add_foreign_key "version_bits", "blocks", column: "deactivate_block_id"
end
