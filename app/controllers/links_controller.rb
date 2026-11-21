class LinksController < ApplicationController
  include GroupScoped
  before_action :set_link, only: %i[ show destroy deliver ]

  def new
    @link = @group.links.build
  end

  def create
    @link = @group.links.build(link_params)
    if @link.save
      if params[:send_now] == "1"
        count = @link.unsent_members.count
        @link.deliver_to_members
        redirect_to group_link_path(@group, @link), notice: "Link saved and emailed to #{count} #{"member".pluralize(count)}."
      else
        redirect_to group_link_path(@group, @link), notice: "Link saved. It has not been emailed yet."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @personal_links = @link.personal_links.includes(:member).order("members.name")
    @unsent_members = @link.unsent_members
    @clicks = @link.clicks.includes(personal_link: :member).reorder(created_at: :desc).limit(200)
  end

  def deliver
    count = @link.unsent_members.count
    @link.deliver_to_members
    redirect_to group_link_path(@group, @link), notice: "Emailed #{count} #{"member".pluralize(count)}."
  end

  def destroy
    @link.destroy!
    redirect_to @group, notice: "Link deleted. Its personal links no longer work.", status: :see_other
  end

  private
    def set_link
      @link = @group.links.find(params[:id])
    end

    def link_params
      params.expect(link: %i[ title url ])
    end
end
