module Intrigue
module Task
module Enrich
class DnsRecord < Intrigue::Task::BaseTask

  def self.metadata
    {
      :name => "enrich/dns_record",
      :pretty_name => "Enrich DnsRecord",
      :authors => ["jcran"],
      :description => "Fills in details for a DnsRecord",
      :references => [],
      :allowed_types => ["DnsRecord"],
      :type => "enrichment",
      :passive => true,
      :example_entities => [
        {"type" => "DnsRecord", "details" => {"name" => "intrigue.io"}}],
      :allowed_options => [],
      :created_types => [
        "DnsRecord",
        "IpAddress",
        "FtpService",
        "MongoService",
        "NetworkService",
        "SmtpService",
        "SnmpService"
      ]
    }
  end

  def run

    lookup_name = _get_entity_name

    # Do a lookup and keep track of all aliases
    results = resolve(lookup_name)
    _log "Creating aliases"
    _create_aliases(results)

    # Create new entities if we found vhosts / aliases
    _log "Creating vhost services"
    _create_vhost_entities(lookup_name)

    _log "Grabbing resolutions"
    _set_entity_detail("resolutions", collect_resolutions(results) )

    _log "Grabbing SOA"
    soa_details = collect_soa_details(lookup_name)
    _set_entity_detail("soa_record", soa_details)
    #check_and_create_domain(soa_details["primary_name_server"]) if soa_details

    # possible we're a tld, so do a whois query
    if soa_details

      # grab whois info
      out = whois(lookup_name)
      if out
        _set_entity_detail("whois_full_text", out["whois_full_text"])
        _set_entity_detail("nameservers", out["nameservers"])
        _set_entity_detail("contacts", out["contacts"])

        # create domains from each of the nameservers
        #if out["nameservers"]
        #  out["nameservers"].each do |n|
        #    check_and_create_domain(n)
        #  end
        #end

      end

    end

    # grab any / all MX records (useful to see who accepts mail)
    _log "Grabbing MX"
    mx_records = collect_mx_records(lookup_name)
    _set_entity_detail("mx_records", mx_records)
    #x_records.each{|mx| check_and_create_domain(mx["host"]) }

    # collect TXT records (useful for random things)
    _log "Grabbing TXT"
    txt_records = collect_txt_records(lookup_name)
    _set_entity_detail("txt_records", txt_records)

    # grab any / all SPF records (useful to see who accepts mail)
    _log "Grabbing SPF"
    spf_details = collect_spf_details(lookup_name)
    _set_entity_detail("spf_record", spf_details)

    # create a domain for this entity
    #check_and_create_domain(lookup_name)

  end

  private

    def _create_aliases(results)
      ####
      ### Create aliased entities
      ####
      results.each do |result|
        _log "Creating entity for... #{result}"
        if "#{result["name"]}".is_ip_address?
          _create_entity("IpAddress", { "name" => result["name"] }, @entity)
        else
          _create_entity("DnsRecord", { "name" => result["name"] }, @entity)
        end
      end
    end

    def _create_vhost_entities(lookup_name)
      ### For each associated IpAddress, make sure we create any additional
      ### uris if we already have scan results
      ###
      @entity.aliases.each do |a|
        next unless a.type_string == "IpAddress" #  only ips
        #next if a.hidden # skip hidden
        existing_ports = a.get_detail("ports")
        if existing_ports
          existing_ports.each do |p|
            _create_network_service_entity(a,p["number"],p["protocol"],{})
          end
        end
      end
    end


end
end
end
end