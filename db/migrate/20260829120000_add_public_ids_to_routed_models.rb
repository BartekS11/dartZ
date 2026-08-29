class AddPublicIdsToRoutedModels < ActiveRecord::Migration[8.1]
  PUBLIC_ID_RANDOM_LENGTH = 16
  PUBLIC_ID_RANDOM_ALPHABET = [*"0".."9", *"A".."Z", *"a".."z"].freeze

  MODELS = {
    matches: "m_",
    tournaments: "t_",
    tournament_entries: "te_",
    tournament_matches: "tm_",
    training_sessions: "tr_",
    legs: "l_",
    turns: "tu_",
    players: "p_"
  }.freeze

  def up
    MODELS.each_key do |table|
      add_column table, :public_id, :string
    end

    MODELS.each do |table, prefix|
      say_with_time "Backfilling public IDs for #{table}" do
        backfill_public_ids(table, prefix)
      end
    end

    MODELS.each_key do |table|
      change_column_null table, :public_id, false
      add_index table, :public_id, unique: true
    end
  end

  def down
    MODELS.each_key do |table|
      remove_index table, :public_id if index_exists?(table, :public_id)
      remove_column table, :public_id
    end
  end

  private

  def backfill_public_ids(table, prefix)
    quoted_table = quote_table_name(table)

    select_all("SELECT id FROM #{quoted_table} WHERE public_id IS NULL").each do |row|
      public_id = next_public_id(table, prefix)
      execute <<~SQL.squish
        UPDATE #{quoted_table}
        SET public_id = #{quote(public_id)}
        WHERE id = #{row.fetch("id")}
      SQL
    end
  end

  def next_public_id(table, prefix)
    loop do
      public_id = "#{prefix}#{random_suffix}"
      exists = select_value(<<~SQL.squish)
        SELECT 1 FROM #{quote_table_name(table)} WHERE public_id = #{quote(public_id)} LIMIT 1
      SQL
      return public_id unless exists
    end
  end

  def random_suffix
    Array.new(PUBLIC_ID_RANDOM_LENGTH) { PUBLIC_ID_RANDOM_ALPHABET[SecureRandom.random_number(PUBLIC_ID_RANDOM_ALPHABET.length)] }.join
  end
end
