class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show edit update destroy ]

  def index
    @groups = Current.user.groups.order(:name)
  end

  def show
    @member = Member.new(group: @group)
    @links = @group.links.includes(:personal_links)
  end

  def new
    @group = Current.user.groups.build
  end

  def create
    @group = Current.user.groups.build(group_params)
    if @group.save
      redirect_to @group, notice: "Group created. Add members next."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @group.update(group_params)
      redirect_to @group, notice: "Group updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @group.destroy!
    redirect_to groups_path, notice: "Group deleted.", status: :see_other
  end

  private
    def set_group
      @group = Current.user.groups.find(params[:id])
    end

    def group_params
      params.expect(group: %i[ name description ])
    end
end
