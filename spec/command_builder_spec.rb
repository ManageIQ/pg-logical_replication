describe PG::LogicalReplication::CommandBuilder do
  subject { described_class.new(ConnectionHelper.source_database_connection) }

  describe "#command_with_options" do
    it "doesn't add options for WITH if none passed" do
      base_command = "CREATE PUBLICATION test FOR ALL TABLES"
      expect(subject.command_with_options(base_command, "WITH", {})).to eq(base_command)
    end

    it "raises if called with anything other than WITH or SET" do
      expect {
        subject.command_with_options("CREATE PUBLICATION test FOR ALL TABLES", "THINGS", {})
      }.to raise_error(PG::LogicalReplication::CommandBuilderError)
    end

    it "raises if called with SET and no options" do
      expect {
        subject.command_with_options("ALTER PUBLICATION test", "SET", {})
      }.to raise_error(PG::LogicalReplication::CommandBuilderError)
    end

    it "raises if called with an invalid option" do
      expect {
        subject.command_with_options("CREATE PUBLICATION test FOR ALL TABLES", "WITH", {"wat" => true})
      }.to raise_error(PG::LogicalReplication::CommandBuilderError)
    end

    context "CREATE PUBLICATION" do
      it "builds options correctly" do
        base_command = "CREATE PUBLICATION test FOR ALL TABLES"
        options      = {"publish" => 'insert, update, delete'}
        command      = subject.command_with_options(base_command, "WITH", options)
        expect(command).to eq("CREATE PUBLICATION test FOR ALL TABLES WITH (\"publish\" = 'insert, update, delete')")
      end
    end

    context "ALTER PUBLICATION" do
      it "builds SET options" do
        base_command = "ALTER PUBLICATION test"
        options      = {"publish" => "insert, update"}
        command      = subject.command_with_options(base_command, "SET", options)
        expect(command).to eq("ALTER PUBLICATION test SET (\"publish\" = 'insert, update')")
      end
    end

    context "CREATE SUBSCRIPTION" do
      it "builds options correctly" do
        base_command = "CREATE SUBSCRIPTION test CONNECTION 'dbname=test' PUBLICATION test"
        options      = {
          "connect"            => true,
          "copy_data"          => true,
          "create_slot"        => false,
          "enabled"            => true,
          "slot_name"          => "test_slot",
          "synchronous_commit" => "off"
        }
        command      = subject.command_with_options(base_command, "WITH", options)
        expected     = "CREATE SUBSCRIPTION test "\
                       "CONNECTION 'dbname=test' "\
                       "PUBLICATION test "\
                       "WITH ("\
                       "\"connect\" = true, "\
                       "\"copy_data\" = true, "\
                       "\"create_slot\" = false, "\
                       "\"enabled\" = true, "\
                       "\"slot_name\" = 'test_slot', "\
                       "\"synchronous_commit\" = 'off'"\
                       ")"
        expect(command).to eq(expected)
      end
    end

    context "ALTER SUBSCRIPTION" do
      it "builds options correctly for SET" do
        base_command = "ALTER SUBSCRIPTION test"
        options      = {
          "enabled"   => false,
          "slot_name" => "test_slot"
        }
        command = subject.command_with_options(base_command, "SET", options)
        expect(command).to eq("ALTER SUBSCRIPTION test SET (\"enabled\" = false, \"slot_name\" = 'test_slot')")
      end

      it "builds options correctly for WITH" do
        base_command = "ALTER SUBSCRIPTION test SET PUBLICATION test, test2"
        options      = {
          "refresh" => false
        }
        command      = subject.command_with_options(base_command, "WITH", options)
        expect(command).to eq("ALTER SUBSCRIPTION test SET PUBLICATION test, test2 WITH (\"refresh\" = false)")
      end
    end
  end

end
