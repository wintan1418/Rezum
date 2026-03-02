class AddTemplateToResumes < ActiveRecord::Migration[7.2]
  def change
    add_column :resumes, :template, :string, default: 'professional'
  end
end
