module Lingohub
  module Models
    require 'lingohub/models/resource'
    require 'lingohub/models/collaborator'

    class Project
      def self.lazy_attr_accessor(*params)
        params.each do |sym|
          define_method(sym) do
            unless defined? @fetched
              fetch
            end
            self.instance_variable_get("@#{sym}")
          end
          define_method("#{sym}=") do |value|
            self.instance_variable_set("@#{sym}", value)
          end
        end
      end


      lazy_attr_accessor(:title, :link, :weburl, :resources_url, :collaborators_url, :invitations_url,
                         :translations_url, :search_url, :unarchive_url, :owner, :description, :opensource, :project_locales)

      def initialize(client, link)
        @client = client
        @link = link
      end

      def create!(attributes={ })
        self.title = attributes[:title]
      end

      def destroy
        @client.delete self.link
      end

      def unarchive
        @client.put self.unarchive_url
      end

      def update(attributes={ })
        @client.put self.link, { :project => attributes }
      end

      def invite_collaborator(email)
        @client.post(self.invitations_url, :invitation => { :email => email })
      end

      def resources
        unless defined? @resources
          @resources = { }
          response = @client.get(self.resources_url)
          resource_hash = JSON.parse(response)
          members = resource_hash["members"]
          members.each do |member|
            @resources[member["name"]] = Lingohub::Models::Resource.new(@client, member["project_locale"], member["links"][0]["href"])
          end
        end
        @resources
      end

      def collaborators
        unless defined? @collaborators
          @collaborators = []
          response = @client.get(self.collaborators_url)
          resource_hash = JSON.parse(response)
          members = resource_hash["members"]
          members.each do |member|
            link = member["link"]["href"] rescue ""
            collaborator = Lingohub::Models::Collaborator.new(@client, link)
            collaborator.email = member["email"]
            collaborator.display_name = member["display_name"]
            collaborator.roles = member["roles"]
            @collaborators << collaborator
          end
        end
        @collaborators
      end

      def download_resource(directory, filename, locale_as_filter = nil)
        raise "Project does not contain that file." unless self.resources.has_key?(filename)
        resource = self.resources[filename]

        if locale_as_filter.nil? || resource_has_locale(resource, locale_as_filter)
          save_to_file(File.join(directory, filename), resource.content)
          true
        else
          false
        end
      end

      def upload_resource(path, locale)
        raise "Path #{path} does not exists" unless File.exists?(path)
        request = { :file => File.new(path, "rb") }
        request.merge!({ :iso2_slug => locale }) if locale
        @client.post(self.resources_url, request)
      end

      def pull_search_results(directory, filename, query, locale = nil)
        parameters = { :filename => filename, :query => query }
        parameters.merge!({ :iso2_slug => locale }) unless locale.nil? or locale.strip.empty?

        content = @client.get(search_url, parameters)
        save_to_file(File.join(directory, filename), content)
      end

      private

      def fetch
        @fetched = true
        response = @client.get @link
        project_hash = JSON.parse(response)
        links = project_hash["links"]
        link = links[0]["href"]
        weburl = links[1]["href"]
        translations_url = links[2]["href"]
        resources_url = links[3]["href"]
        collaborators_url = links[4]["href"]
        invitations_url = links[5]["href"]
        search_url = links[6]["href"]
        unarchive_url = links[7]["href"]

        init_attributes :title => project_hash["title"], :link => link, :weburl => weburl,
                        :owner => project_hash["owner_email"], :description => project_hash["description"],
                        :opensource => project_hash["opensource"], :project_locales => project_hash["project_locales"],
                        :translations_url => translations_url, :resources_url => resources_url,
                        :collaborators_url => collaborators_url, :invitations_url => invitations_url,
                        :search_url => search_url,
                        :unarchive_url => unarchive_url
      end

      def init_attributes(attributes)
        attributes.each_pair do |key, value|
          unless self.instance_variable_get("@#{key}")
            self.send "#{key}=", value
          end
        end
      end

      def save_to_file(path, content)
        File.open(path, 'w+') { |f| f.write(content) }
      end

      def resource_has_locale(resource, locale_as_filter)
        resource.locale == locale_as_filter
      end
    end
  end
end
