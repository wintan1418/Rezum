class AddAtsAnalysisToResumes < ActiveRecord::Migration[7.2]
  def change
    add_column :resumes, :ats_analysis, :text
  end
end
