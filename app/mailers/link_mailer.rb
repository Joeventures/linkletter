class LinkMailer < ApplicationMailer
  def personal_link
    @personal_link = params[:personal_link]
    @link = @personal_link.link
    @member = @personal_link.member
    @group = @link.group
    @url = personal_redirect_url(@personal_link.token)

    mail to: email_address_with_name(@member.email_address, @member.name),
         subject: @link.title.presence || "A new link from #{@group.name}"
  end
end
