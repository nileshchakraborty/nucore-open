class AddMonetaryCapToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :monetary_cap, :decimal, precision: 10, scale: 2
  end
end
