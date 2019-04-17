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

ActiveRecord::Schema.define(version: 2019_04_17_085001) do

  create_table "blocks", force: :cascade do |t|
    t.string "block_hash"
    t.integer "height"
    t.integer "timestamp"
    t.string "work"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "parent_id"
    t.integer "mediantime"
    t.integer "first_seen_by_id"
    t.integer "version"
    t.boolean "is_btc", default: false
    t.index ["block_hash"], name: "index_blocks_on_block_hash", unique: true
    t.index ["first_seen_by_id"], name: "index_blocks_on_first_seen_by_id"
    t.index ["is_btc"], name: "index_blocks_on_is_btc"
    t.index ["parent_id"], name: "index_blocks_on_parent_id"
  end

  create_table "invalid_blocks", force: :cascade do |t|
    t.integer "block_id"
    t.integer "node_id"
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["node_a_id"], name: "index_lags_on_node_a_id"
    t.index ["node_b_id"], name: "index_lags_on_node_b_id"
  end

  create_table "nodes", force: :cascade do |t|
    t.string "name"
    t.integer "version"
    t.integer "block_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "unreachable_since"
    t.string "coin"
    t.integer "common_block_id"
    t.string "rpchost"
    t.string "rpcuser"
    t.string "rpcpassword"
    t.integer "common_height"
    t.boolean "ibd"
    t.integer "peer_count"
    t.index ["block_id"], name: "index_nodes_on_block_id"
    t.index ["common_block_id"], name: "index_nodes_on_common_block_id"
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

end
