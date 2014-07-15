module PRGMQ
  module CAP
    class User
        attr_reader :name, :groups

        def initialize(name, groups)
          # if for some reason a user wasn't configured with a proper
          # group, we'll error out. This will let the admins know
          # to properly configure the user.
          raise MissingUserGroup if groups == nil
          raise InvalidUserGroup if groups.class != Array
          @name = name
          # By default, always add the 'all' group.
          # This group doesn't need to be stored in the server, since
          # all users belong to it, always.
          @groups = groups
          @groups.push "all" unless @groups.include? "all"
        end

    end
  end
end
