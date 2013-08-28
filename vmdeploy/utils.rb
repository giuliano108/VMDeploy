module VMDeploy

    def self.human_byte_size_to_mib s
        suffixes = {'GB' => 1024, 'MB' => 1}
        s.sub!(/\s*([a-zA-Z]+)$/,'')
        suff = $1
        fail "No suffix given, specify one of #{suffixes.keys.to_json}" if suff.nil? || suff.empty?
        fail "Unknown suffix \"#{suff}\"" unless suffixes.keys.include? suff
        s.to_i * suffixes[suff]
    end

end
