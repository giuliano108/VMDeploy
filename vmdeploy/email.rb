require 'pony'
require 'haml'

module VMDeploy::Email
    class Mailer
        def self.send(from, to, subject, body)
            Pony.mail(:from => from,
                      :to => to,
                      :via => VMDeploy[:pony_via],
                      :via_options => VMDeploy[:pony_options],
                      :headers => { 'Content-Type' => 'text/html' },
                      :subject => subject,
                      :body => body)
        end
    end

    class Report
        class << self
            attr_reader :template
            def render(locals)
                Haml::Engine.new(self.template).render(Object.new,locals)
            end
        end
    end

    class Success < Report
        @template = <<'EOM'
#mailreport{:style => 'font-family: "Droid Sans", Helvetica, Arial, sans-serif; font-size: 12pt;'}
  %table{:cellpadding => '3px', :style => 'border-collapse: collapse; border-bottom: 3px solid #DFF0D8;'}
    %tr{:style => 'background: #DFF0D8; color: #528353;'}
      %td{:colspan => 2, :style => 'border-left: 3px solid #DFF0D8; border-right: 3px solid #DFF0D8; padding-left: 2em; padding-right: 2em; padding-top: 5px; padding-bottom: 5px;'}
        %b= params['vmname']
        has been deployed&hellip;
    %tr
      %td{:style => 'border-left: 3px solid #DFF0D8; padding-left: 2em; padding-right: 2em; color: #888;'} IP address
      %td{:style => 'border-right: 3px solid #DFF0D8; padding-left: 2em; padding-right: 2em;'}= ip
    - params.each do |k,v|
      %tr
        %td{:style => 'width: 10em; border-left: 3px solid #DFF0D8; padding-left: 2em; padding-right: 2em; color: #888;'}
          #{k.to_s}
        %td{:style => 'border-right: 3px solid #DFF0D8; padding-left: 2em; padding-right: 2em;'}
          #{v.to_s}
EOM
    end

    class Failure < Report
        @template = <<'EOM'
#mailreport{:style => 'font-family: "Droid Sans", Helvetica, Arial, sans-serif; font-size: 12pt;'}
  %div{:style => 'background: #F2DEDE; color: #B94A48; padding-left: 2em; padding-right: 2em; padding-top: 5px; padding-bottom: 5px;'}
    There was an error deploying
    %b= params['vmname']
    &hellip;
  %div{:style => 'font-family: Monaco, Menlo, Consolas, "Courier New", monospace; background-color: #f5f5f5; padding: 1em 2em 1em 2em;'}= message
  %div{:style => 'background: #F2DEDE; color: #B94A48; padding-left: 2em; padding-right: 2em; padding-top: 5px; padding-bottom: 5px;'}
    Please mail
    %a{:href => "mailto:#{support_email}", :style => 'text-decoration: none; color: #B94A48; font-weight: bold;'}= support_email
    for help
EOM
    end

end
