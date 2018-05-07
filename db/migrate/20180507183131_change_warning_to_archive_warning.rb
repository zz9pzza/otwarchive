class ChangeWarningToArchiveWarning < ActiveRecord::Migration[5.1]
  def up
    execute "UPDATE tags SET type = 'Archivewarning' WHERE type = 'Warning'"
    rename_column :prompt_restrictions, :warning_num_allowed, :archivewarning_num_allowed
    rename_column :prompt_restrictions, :warning_num_required, :archivewarning_num_required
    rename_column :prompt_restrictions, :require_unique_warning, :require_unique_archivewarning
    rename_column :prompt_restrictions, :allow_any_warning, :allow_any_archivewarning
    rename_column :prompts, :any_warning, :any_archivewarning
  end

  def down
    execute "UPDATE tags SET type = 'Warning' WHERE type = 'Archivewarning'"
    rename_column :prompt_restrictions, :archivewarning_num_allowed ,:warning_num_allowed
    rename_column :prompt_restrictions, :archivewarning_num_required, :warning_num_required
    rename_column :prompt_restrictions, :require_unique_archivewarning, :require_unique_warning
    rename_column :prompt_restrictions, :allow_any_archivewarning, :allow_any_warning
    rename_column :prompts, :any_archivewarning,  :any_warning
  end
end
