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

ActiveRecord::Schema.define(version: 2019_01_21_113950) do

  create_table "blocks", force: :cascade do |t|
    t.string "block_hash"
    t.integer "height"
    t.integer "timestamp"
    t.string "work"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["block_hash"], name: "index_blocks_on_block_hash", unique: true
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
    t.index ["block_id"], name: "index_nodes_on_block_id"
    t.index ["common_block_id"], name: "index_nodes_on_common_block_id"
  end

end
