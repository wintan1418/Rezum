module Admin
  class LeadsController < BaseController
    def index
      @leads = Lead.recent
      @leads = @leads.where(source: params[:source]) if params[:source].present?
      @leads = @leads.where("email ILIKE ?", "%#{params[:q]}%") if params[:q].present?

      @total = Lead.count
      @today = Lead.where("created_at >= ?", Date.current.beginning_of_day).count
      @this_week = Lead.where("created_at >= ?", 7.days.ago).count
      @sources = Lead.group(:source).count.sort_by { |_, v| -v }
    end

    def destroy
      Lead.find(params[:id]).destroy
      redirect_to admin_leads_path, notice: "Lead deleted."
    end

    def export
      leads = Lead.recent
      leads = leads.where(source: params[:source]) if params[:source].present?

      csv_data = CSV.generate(headers: true) do |csv|
        csv << ["Email", "Source", "IP Address", "Date"]
        leads.find_each do |lead|
          csv << [lead.email, lead.source, lead.ip_address, lead.created_at.strftime("%Y-%m-%d %H:%M")]
        end
      end

      send_data csv_data, filename: "leads-#{Date.current}.csv", type: "text/csv"
    end
  end
end
