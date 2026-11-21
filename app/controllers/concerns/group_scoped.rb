# Loads the group from the URL, scoped to the signed-in user so one account can
# never read or modify another account's groups, members, links, or clicks.
module GroupScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_group
  end

  private
    def set_group
      @group = Current.user.groups.find(params[:group_id])
    end
end
