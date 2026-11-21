class MembersController < ApplicationController
  include GroupScoped
  before_action :set_member, only: %i[ edit update destroy ]

  def create
    @member = @group.members.build(member_params)
    if @member.save
      redirect_to @group, notice: "#{@member.name} added."
    else
      redirect_to @group, alert: @member.errors.full_messages.to_sentence
    end
  end

  # Bulk add: one member per line as "Name, email" or "Name <email>".
  def import
    added, failed = 0, []
    params[:members_text].to_s.lines.map(&:strip).reject(&:blank?).first(1000).each do |line|
      name, email = parse_line(line)
      member = Member.new(group: @group, name: name, email_address: email)
      if member.save
        added += 1
      else
        failed << "#{line} (#{member.errors.full_messages.to_sentence})"
      end
    end

    flash[:notice] = "#{added} #{"member".pluralize(added)} added."
    flash[:alert] = "Skipped: #{failed.first(5).join('; ')}" if failed.any?
    redirect_to @group
  end

  def edit
  end

  def update
    if @member.update(member_params)
      redirect_to @group, notice: "Member updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @member.destroy!
    redirect_to @group, notice: "#{@member.name} removed.", status: :see_other
  end

  private
    def set_member
      @member = @group.members.find(params[:id])
    end

    def member_params
      params.expect(member: %i[ name email_address ])
    end

    def parse_line(line)
      if (m = line.match(/\A(.*?)\s*<([^>]+)>\z/))
        [ m[1].delete('"'), m[2] ]
      else
        name, email = line.split(/[,\t;]/, 2).map { |s| s.to_s.strip }
        email.blank? && name.include?("@") ? [ name.split("@").first, name ] : [ name, email ]
      end
    end
end
