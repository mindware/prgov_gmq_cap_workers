# We use resolv to validate IPv4 & Ipv6 addresses. It is better
# than ipaddr (ipaddr uses socket lib to validate can trigger dns lookups)
require 'resolv'
require 'date'
require 'base64'                 # used to validate certificates

# A module for methods used to validate data, such as valid
# transaction parameters, social security numbers, emails and the like.
module PRGMQ
  module CAP
    module Validations
        ########################################
        ##            Constants:               #
        ########################################

        SSN_LENGTH              = 9       # In 2014 SSN length was 9 digits.
        MAX_EMAIL_LENGTH        = 254     # IETF maximum length RFC3696/Errata ID: 1690
        DTOP_ID_MAX_LENGTH      = 20      # Arbitrarily selected length. Review this!
        PRPD_USER_ID_MAX_LENGTH = 255     # Arbitrarily selected length. Review this!
        MAX_NAME_LENGTH         = 255     # Max length for individual components of
                                          # a full name (name, middle, last names)
        MAX_FULLNAME_LENGTH     = 255     # Max length for full name. 255 is long
                                          # enough. 255 * 255 * 255 * 255 is way too
                                          # too much anyway. Used for analyst names.
        MAX_RESIDENCY_LENGTH    = 255     # max residency length
        MINIMUM_AGE             = 18      # Edad minima para solicitar un certificado

        DATE_FORMAT             = '%d/%m/%Y'  # day/month/year

        ########################################
        ##            Validations:             #
        ########################################

        # used when SIJC specifies the certificate is ready
        def validate_certificate_ready_parameters(params)
          params["id"] = params["tx_id"] if !params["tx_id"].nil?
          raise MissingTransactionId     if params["id"].to_s.length == 0
          raise InvalidTransactionId     if !validate_transaction_id(params["id"])
          raise MissingCertificateBase64 if params["certificate_base64"].to_s.length == 0
          raise InvalidCertificateBase64 if !validate_certificate_base64(params["certificate_base64"])
          return params
        end

        # used when an PRPD analyst specifies it has completed a manual review
        def validate_review_completed_parameters(params)
          raise MissingTransactionId        if params["id"].to_s.length == 0
          raise InvalidTransactionId        if !validate_transaction_id(params["id"])

          raise MissingAnalystId            if params["analyst_id"].to_s.length == 0
          raise InvalidAnalystId            if !validate_analyst_id(params["analyst_id"])
          raise MissingAnalystFullname      if params["analyst_fullname"].to_s.length == 0
          raise InvalidAnalystFullname      if !validate_analyst_fullname(params["analyst_fullname"])

          raise MissingAnalystApprovalDate  if params["analyst_approval_datetime"].to_s.length == 0
          raise InvalidAnalystApprovalDate  if !validate_date(params["analyst_approval_datetime"])
          raise MissingAnalystTransactionId if params["analyst_transaction_id"].to_s.length == 0
          raise MissingAnalystInternalStatusId if params["analyst_internal_status_id"].to_s.length == 0
          raise MissingAnalystDecisionCode     if params["decision_code"].to_s.length == 0
          raise InvalidAnalystDecisionCode     if !validate_decision_code(params["decision_code"])
          return params
        end

        # validates parameters in a hash, returning proper errors
        # removed any non-whitelisted params
        def validate_transaction_creation_parameters(params, whitelist)

          # delets all non-whitelisted params, and returns a safe list.
          params = trim_whitelisted(params, whitelist)

          # Return proper errors if parameter is missing:
          raise MissingEmail           if params["email"].to_s.length == 0
          raise MissingSSN             if params["ssn"].to_s.length == 0
          raise MissingLicenseNumber   if params["license_number"].to_s.length == 0
          raise MissingFirstName       if params["first_name"].to_s.length == 0
          raise MissingLastName        if params["last_name"].to_s.length == 0
          raise MissingResidency       if params["residency"].to_s.length == 0
          raise MissingBirthDate       if params["birth_date"].to_s.length == 0
          raise MissingClientIP        if params["IP"].to_s.length == 0
          raise MissingReason          if params["reason"].to_s.length == 0
          raise MissingLanguage        if params["language"].to_s.length == 0

          # Validate the Email
          raise InvalidEmail           if validate_email(params["email"])

          # Validate the SSN
          # we eliminate any potential dashes in ssn
          params["ssn"]                 = params["ssn"].gsub("-", "").strip
          raise InvalidSSN             if !validate_ssn(params["ssn"])

          # Validate the DTOP id:
          raise InvalidLicenseNumber   if !validate_dtop_id(params["license_number"])

          raise InvalidFirstName       if !validate_name(params["first_name"])
          raise InvalidMiddleName      if !params["middle_name"].nil? and
                                          !validate_name(params["middle_name"])
          raise InvalidLastName        if !validate_name(params["last_name"])
          raise InvalidMotherLastName  if !params["mother_last_name"].nil? and
                                          !validate_name(params["mother_last_name"])

          raise InvalidResidency       if !validate_residency(params["residency"])

          # This validates birthdate
          raise InvalidBirthDate       if !validate_birthdate(params["birth_date"])
          # This checks minimum age
          raise InvalidBirthDate       if !validate_birthdate(params["birth_date"], true)
          raise InvalidClientIP        if !validate_ip(params["IP"])
          raise InvalidReason          if params["reason"].to_s.strip.length > 255
          raise InvalidLanguage        if !validate_language(params["language"])

          return params
        end

        # Validates that a user specified language has been added.
        def validate_language(params)
          if(params.to_s == "english" or params.to_s == "spanish")
            true
          else
            false
          end
        end

        # Given a set of params and an array of whitelisted keys, we
        # delete all keys that weren't invited to the party. No sneaky
        # params allowed in this joint.
        def trim_whitelisted(params, whitelist)
            # remove any parameters that are not whitelisted
            params.each do |key, value|
              # if white listed
              if whitelist.include? key
                # strip the parameters of any extra spaces, save as string
                params[key] = value.to_s.strip
              else
                # delete any unauthorized parameters
                params.delete key
              end
            end
            params
        end

        def validate_decision_code(code)
          # return true
          if (code.to_s == "100" or code.to_s == "200")
            true
          else
            false
          end
        end
        # Validates a date as UTC
        def validate_date(date)
          begin
            Date.parse(date.to_s)
            true
          rescue ArgumentError
            false
          end
        end

        # Validtes a valid 64 bit was received. Doesn't validate that its
        # a specifif filetype in order to be flexible, and allow for
        # different filetypes to be sent in the future, not just pdf.
        def validate_certificate_base64(cert)
          return false if(cert.to_s.length <= 0 )
          # try to decode it by loading the entire decoded thing in memory
          begin
            # A tolerant verification
            # We'll use this only if SIJC's certificates fail in the
            # initial trials, else, we'll stick to the strict one.
            # Next line complies just with RC 2045:
            # decode = Base64.decode64(cert)

            # A strict verification:
            # Next line complies with RFC 4648:
            # try to decode, ArgumentErro is raised
            # if incorrectly padded or contains non-alphabet characters.
            decode = Base64.strict_decode64(cert)

            # Once decoded release it from memory
            decode = nil
            return true
          rescue Exception => e
            return false
          end
        end
        def validate_transaction_id(id)
          # if(puts "#{id.length} vs #{TransactionIdFactory.transaction_key_length()}")
          if(id.to_s.strip.length == TransactionIdFactory.transaction_key_length())
             return true
          end
          return false
        end

        # Validate Social Security Number
        def validate_ssn(value)
          value = value.to_s
          # validates if its an integer
          if(validate_str_is_integer(value) and value.length == SSN_LENGTH)
            return true
          else
            return false
          end
        end

        # Check the email address
        def validate_email(value)
          # For email length, the source was:
          # http://www.rfc-editor.org/errata_search.php?rfc=3696&eid=1690
          #
          # Optionally we could force DNS lookups using ValidatesEmailFormatOf
          # by sending validate_email_format special options after the value
          # such as mx=true (see gem's github), however, this requires dns
          # availability 24/7, and we'd like this system to work a little more
          # independently, so for now simply check against the RFC 2822,
          # RFC 3696 and the filters in the gem.
          return true if (ValidatesEmailFormatOf::validate_email_format(value).nil? and
                   value.to_s.length > MAX_EMAIL_LENGTH )
          return false
        end

        # validates if a string is an integer
        def validate_str_is_integer(value)
          !!(value =~ /\A[-+]?[0-9]+\z/)
        end

        # Validates a DTOP id
        def validate_dtop_id(value)
          return false if(!validate_str_is_integer(value) or
                    value.to_s.length >= DTOP_ID_MAX_LENGTH )
          return true
        end

        def validate_analyst_id(value)
          return false if(value.to_s.length >= PRPD_USER_ID_MAX_LENGTH)
          return true
        end

        def validate_analyst_fullname(value)
          return false if(value.to_s.length >= MAX_FULLNAME_LENGTH)
          return true
        end

        # used to validate names/middle names/last names/mother last name
        def validate_name(value)
          return false if(value.to_s.length >= MAX_NAME_LENGTH)
          return true
        end

        def validate_residency(value)
          return false if(value.to_s.length >= MAX_RESIDENCY_LENGTH)
          return true
        end

        def validate_birthdate(value, check_age=false)
          begin
            # check if valid date. if invalid, raise exception ArgumentError
            date = Date.strptime(value, DATE_FORMAT)
            # if it was required for us to validate minimum age
            if(check_age == true)
              if(age(date) >= MINIMUM_AGE)
                return true # date was valid and the person is at least of minimum age
              end
              return false # person isn't of minimum age
            end
            return true # the date is valid
          rescue Exception => e
            # ArgumentError, the user entered an invalid date.
            return false
          end
        end

        # Gets the age of a person based on their date of birth (dob)
        def age(dob)
          now = Date.today
          now.year - dob.year - ((now.month > dob.month ||
          (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
        end

        ###################################
        #  Validate IPv4 and IPv6         #
        ###################################
        def validate_ip(value)
          case value
          when Resolv::IPv4::Regex
            return true
          when Resolv::IPv6::Regex
            return true
          else
            return false
          end
        end
    end
  end
end

# Ripped from https://github.com/alexdunae/validates_email_format_of
# and modified so it doesn't have any dependency on ActiveRecord.
# encoding: utf-8
module ValidatesEmailFormatOf

  VERSION = '1.5.3'

  LocalPartSpecialChars = /[\!\#\$\%\&\'\*\-\/\=\?\+\-\^\_\`\{\|\}\~]/

  def self.validate_email_domain(email)
    domain = email.match(/\@(.+)/)[1]
    Resolv::DNS.open do |dns|
      @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX) + dns.getresources(domain, Resolv::DNS::Resource::IN::A)
    end
    @mx.size > 0 ? true : false
  end

  # Validates whether the specified value is a valid email address.  Returns nil if the value is valid, otherwise returns an array
  # containing one or more validation error messages.
  #
  # Configuration options:
  # * <tt>message</tt> - A custom error message (default is: "does not appear to be valid")
  # * <tt>check_mx</tt> - Check for MX records (default is false)
  # * <tt>mx_message</tt> - A custom error message when an MX record validation fails (default is: "is not routable.")
  # * <tt>with</tt> The regex to use for validating the format of the email address (deprecated)
  # * <tt>local_length</tt> Maximum number of characters allowed in the local part (default is 64)
  # * <tt>domain_length</tt> Maximum number of characters allowed in the domain part (default is 255)
  def self.validate_email_format(email, options={})
      default_options = { :message => 'does not appear to be valid',
                          :check_mx => false,
                          :mx_message => 'is not routable',
                          :domain_length => 255,
                          :local_length => 64
                          }
      opts = options.merge(default_options) {|key, old, new| old}  # merge the default options into the specified options, retaining all specified options

      email = email.strip if email

      begin
        domain, local = email.reverse.split('@', 2)
      rescue
        return [ opts[:message] ]
      end

      # need local and domain parts
      return [ opts[:message] ] unless local and not local.empty? and domain and not domain.empty?

      # check lengths
      return [ opts[:message] ] unless domain.length <= opts[:domain_length] and local.length <= opts[:local_length]

      local.reverse!
      domain.reverse!

      if opts.has_key?(:with) # holdover from versions <= 1.4.7
        return [ opts[:message] ] unless email =~ opts[:with]
      else
        return [ opts[:message] ] unless self.validate_local_part_syntax(local) and self.validate_domain_part_syntax(domain)
      end

      if opts[:check_mx] and !self.validate_email_domain(email)
        return [ opts[:mx_message] ]
      end

      return nil    # represents no validation errors
  end


  def self.validate_local_part_syntax(local)
    in_quoted_pair = false
    in_quoted_string = false

    (0..local.length-1).each do |i|
      ord = local[i].ord

      # accept anything if it's got a backslash before it
      if in_quoted_pair
        in_quoted_pair = false
        next
      end

      # backslash signifies the start of a quoted pair
      if ord == 92 and i < local.length - 1
        return false if not in_quoted_string # must be in quoted string per http://www.rfc-editor.org/errata_search.php?rfc=3696
        in_quoted_pair = true
        next
      end

      # double quote delimits quoted strings
      if ord == 34
        in_quoted_string = !in_quoted_string
        next
      end

      next if local[i,1] =~ /[a-z0-9]/i
      next if local[i,1] =~ LocalPartSpecialChars

      # period must be followed by something
      if ord == 46
        return false if i == 0 or i == local.length - 1 # can't be first or last char
        next unless local[i+1].ord == 46 # can't be followed by a period
      end

      return false
    end

    return false if in_quoted_string # unbalanced quotes

    return true
  end

  def self.validate_domain_part_syntax(domain)
    parts = domain.downcase.split('.', -1)

    return false if parts.length <= 1 # Only one domain part

    # Empty parts (double period) or invalid chars
    return false if parts.any? {
      |part|
        part.nil? or
        part.empty? or
        not part =~ /\A[[:alnum:]\-]+\Z/ or
        part[0,1] == '-' or part[-1,1] == '-' # hyphen at beginning or end of part
    }

    # ipv4
    return true if parts.length == 4 and parts.all? { |part| part =~ /\A[0-9]+\Z/ and part.to_i.between?(0, 255) }

    return false if parts[-1].length < 2 or not parts[-1] =~ /[a-z\-]/ # TLD is too short or does not contain a char or hyphen

    return true
  end

  module Validations
    # Validates whether the value of the specified attribute is a valid email address
    #
    #   class User < ActiveRecord::Base
    #     validates_email_format_of :email, :on => :create
    #   end
    #
    # Configuration options:
    # * <tt>message</tt> - A custom error message (default is: "does not appear to be valid")
    # * <tt>on</tt> - Specifies when this validation is active (default is :save, other options :create, :update)
    # * <tt>allow_nil</tt> - Allow nil values (default is false)
    # * <tt>allow_blank</tt> - Allow blank values (default is false)
    # * <tt>check_mx</tt> - Check for MX records (default is false)
    # * <tt>mx_message</tt> - A custom error message when an MX record validation fails (default is: "is not routable.")
    # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
    #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
    #   method, proc or string should return or evaluate to a true or false value.
    # * <tt>unless</tt> - See <tt>:if</tt>
    def validates_email_format_of(*attr_names)
      options = { :on => :save,
        :allow_nil => false,
        :allow_blank => false }
      options.update(attr_names.pop) if attr_names.last.is_a?(Hash)

      validates_each(attr_names, options) do |record, attr_name, value|
        errors = ValidatesEmailFormatOf::validate_email_format(value.to_s, options)
        errors.each do |error|
          record.errors.add(attr_name, error)
        end unless errors.nil?
      end
    end
  end
end
