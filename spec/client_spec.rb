describe PG::LogicalReplication::Client do
  let(:pub_connection) { ConnectionHelper.source_database_connection }
  let(:sub_connection) { ConnectionHelper.target_database_connection }

  let(:pub_client) { described_class.new(pub_connection) }
  let(:sub_client) { described_class.new(sub_connection) }

  let(:pub_name) { "test_pub" }
  let(:sub_name) { "test_sub" }

  before(:all) { DatabaseHelper.create_tables }

  around do |example|
    DatabaseHelper.with_clean_environment { example.call }
  end

  describe "#create_publication" do
    it "creates a publication for no tables" do
      pub_client.create_publication(pub_name)

      included_tables = pub_client.tables_in_publication(pub_name)
      expect(included_tables).to be_empty
    end

    it "creates a publication for all tables" do
      pub_client.create_publication(pub_name, true)
      publication = pub_client.publications.first

      expect(publication["name"]).to eq(pub_name)
      expect(publication["puballtables"]).to be true
    end

    it "creates a publication for some tables" do
      tables = DatabaseHelper.tables[0..1]
      pub_client.create_publication(pub_name, false, tables)
      publication = pub_client.publications.first

      expect(publication["name"]).to eq(pub_name)
      expect(publication["puballtables"]).to be false

      included_tables = pub_client.tables_in_publication(pub_name)
      expect(included_tables).to match_array(tables)
    end

    it "creates a publication for only some operations" do
      pub_client.create_publication(pub_name, true, [], {'publish' => 'insert, update'})
      publication = pub_client.publications.first

      expect(publication["name"]).to eq(pub_name)
      expect(publication["pubinsert"]).to be true
      expect(publication["pubupdate"]).to be true
      expect(publication["pubdelete"]).to be false
    end
  end

  describe "#add_tables_to_publication" do
    it "adds the given tables" do
      pub_client.create_publication(pub_name)

      tables = DatabaseHelper.tables[0..1]
      pub_client.add_tables_to_publication(pub_name, tables)

      included_tables = pub_client.tables_in_publication(pub_name)
      expect(included_tables).to match_array(tables)
    end
  end

  describe "#set_publication_tables" do
    it "configures the publication for the given tables" do
      pub_client.create_publication(pub_name, false, [DatabaseHelper.tables.first])

      tables = DatabaseHelper.tables[1..3]
      pub_client.set_publication_tables(pub_name, tables)

      included_tables = pub_client.tables_in_publication(pub_name)
      expect(included_tables).to match_array(tables)
    end
  end

  describe "#remove_tables_from_publication" do
    it "removes the given tables" do
      pub_client.create_publication(pub_name, false, DatabaseHelper.tables[0..2])

      pub_client.remove_tables_from_publication(pub_name, [DatabaseHelper.tables.first])

      included_tables = pub_client.tables_in_publication(pub_name)
      expect(included_tables).to match_array(DatabaseHelper.tables[1..2])
    end
  end

  context "with a simple publication" do
    before { pub_client.create_publication(pub_name) }

    let(:publication) { pub_client.publications.first }

    describe "#publishes?" do
      it "returns true for and existing publication" do
        expect(pub_client.publishes?(pub_name)).to be true
      end

      it "returns false for a non-existing publication" do
        expect(pub_client.publishes?("foo")).to be false
      end
    end

    describe "#alter_publication_options" do
      it "changes which operations are replicated" do
        pub_client.alter_publication_options(pub_name, {'publish' => 'insert'})

        expect(publication["name"]).to eq(pub_name)
        expect(publication["pubinsert"]).to be true
        expect(publication["pubupdate"]).to be false
        expect(publication["pubdelete"]).to be false
      end
    end

    describe "#set_publication_owner" do
      it "changes the owner of the publication" do
        pub_client.set_publication_owner(pub_name, "postgres")
        expect(publication["owner"]).to eq("postgres")
      end
    end

    describe "#rename_publication" do
      it "changes the publication name" do
        pub_client.rename_publication(pub_name, "new_name")
        expect(publication["name"]).to eq("new_name")
      end
    end

    describe "#drop_publication" do
      it "removes the publication" do
        pub_client.drop_publication(pub_name)
        expect(publication).to be_nil
        expect { pub_client.drop_publication(pub_name, true) }.not_to raise_error
      end
    end
  end

  context "with a subscription" do
    let(:subscription_conninfo) { pub_connection.conninfo_hash.delete_if { |k, v| v == "" || v.nil? } }

    before do
      pub_client.create_publication(pub_name, true)
      create_subscription
    end

    # The create subscription command will hang if we try to create a subscription to a publication
    # on the same database cluster. Because of this, there is really only one way we can create
    # a subscription so we'll put all that work into a method and test everything else using this
    # subscription.
    # See: https://www.postgresql.org/docs/10/sql-createsubscription.html
    def create_subscription
      pub_connection.async_exec("select pg_create_logical_replication_slot('#{sub_name}', 'pgoutput')")
      sub_options = {
        'create_slot' => false,
        'slot_name'   => sub_name
      }
      sub_client.create_subscription(sub_name, subscription_conninfo, [pub_name], sub_options)
    end

    describe "#subscriptions" do
      it "filters the subscriptions by database name" do
        expect(sub_client.subscriptions.count).to eq(1)
        expect(sub_client.subscriptions("foo").count).to eq(0)
        expect(sub_client.subscriptions("logical_test_target").count).to eq(1)
      end
    end

    describe "#subscriber?" do
      it "returns true if there is a subscription" do
        expect(sub_client.subscriber?).to be true
      end

      # Databases on the same cluster share the subscription information
      it "returns true from publisher" do
        expect(pub_client.subscriber?).to be true
      end

      it "returns true from subscriber if subscriber database specified" do
        expect(sub_client.subscriber?(sub_connection.db)).to be true
      end

      it "returns false from subscriber if publisher database specified" do
        expect(sub_client.subscriber?(pub_connection.db)).to be false
      end

      it "returns false from publisher if publisher database specified" do
        expect(pub_client.subscriber?(pub_connection.db)).to be false
      end

      it "returns false if there are no subscriptions" do
        sub_client.drop_subscription(sub_name)
        expect(sub_client.subscriber?).to be false
      end
    end

    describe "#create_subscription" do
      it "creates a subscription for the given publication" do
        subs = sub_client.subscriptions
        expect(subs.count).to eq(1)

        sub = subs.first
        expect(sub["subscription_name"]).to eq(sub_name)
        expect(sub["database_name"]).to eq("logical_test_target")
        expect(sub["enabled"]).to be true
        expect(sub["publications"]).to eq([pub_name])
      end
    end

    describe "#drop_subscription" do
      it "removes a subscription" do
        sub_client.drop_subscription(sub_name)
        expect(sub_client.subscriptions.count).to eq(0)
        expect { sub_client.drop_subscription(sub_name, true) }.not_to raise_error
      end
    end

    describe "#set_subscription_conninfo" do
      it "alters the subscription conninfo string" do
        new_conninfo = subscription_conninfo.merge({"fallback_application_name" => "things"})
        sub_client.set_subscription_conninfo(sub_name, new_conninfo)
        expect(sub_client.subscriptions.first["subscription_dsn"]).to include("fallback_application_name='things'")
      end
    end

    describe "#set_subscription_publications" do
      let(:new_pub_name) { "other_publication" }
      before { pub_client.create_publication(new_pub_name, true) }

      it "adds the publication to the subscription" do
        sub_client.set_subscription_publications(sub_name, [pub_name, new_pub_name])
        expect(sub_client.subscriptions.first["publications"]).to match_array([pub_name, new_pub_name])
      end

      it "adds the publication to the subscription with options" do
        sub_client.set_subscription_publications(sub_name, [pub_name, new_pub_name], 'refresh' => true, 'copy_data' => false)
        expect(sub_client.subscriptions.first["publications"]).to match_array([pub_name, new_pub_name])
      end
    end

    describe "#sync_subscription" do
      it "refreshes the subscription with new publication data" do
        # TODO: Not sure what to test here, but I want to run through the method execution
        expect { sub_client.sync_subscription(sub_name, 'copy_data' => true) }.not_to raise_error
      end
    end

    describe "#disable_subscription" do
      it "disables the subscription" do
        sub_client.disable_subscription(sub_name)

        subscription = sub_client.subscriptions.first
        expect(subscription["enabled"]).to be false
      end
    end

    describe "#enable_subscription" do
      it "enables the subscription" do
        sub_client.disable_subscription(sub_name)
        sub_client.enable_subscription(sub_name)

        subscription = sub_client.subscriptions.first
        expect(subscription["enabled"]).to be true
      end
    end

    describe "#alter_subscription_options" do
      it "changes the options provided by CREATE SUBSCRIPTION" do
        new_slot_name = "some_slot"
        old_slot_name = sub_client.subscriptions.first["slot_name"]

        # sanity - if this fails the test is invalid
        expect(old_slot_name).not_to eq(new_slot_name)

        sub_client.alter_subscription_options(sub_name, 'slot_name' => new_slot_name)
        expect(sub_client.subscriptions.first["slot_name"]).to eq(new_slot_name)

        # set it back so that the subscription can be dropped without error
        sub_client.alter_subscription_options(sub_name, 'slot_name' => old_slot_name)
      end
    end

    describe "#set_subscription_owner" do
      it "changes the owner of the subscription" do
        sub_client.set_subscription_owner(sub_name, "postgres")
        expect(sub_client.subscriptions.first["owner"]).to eq("postgres")
      end
    end

    describe "#rename_subscription" do
      it "changes the name of the subscription" do
        sub_client.rename_subscription(sub_name, "new_subscription_name")
        expect(sub_client.subscriptions.first["subscription_name"]).to eq("new_subscription_name")
      end
    end

    describe "#lag_bytes" do
      it "queries for replication lag" do
        expect(pub_client.lag_bytes).to be
      end
    end

    describe "#wal_retained_bytes" do
      it "queries for amount of wal retained" do
        expect(pub_client.wal_retained_bytes).to be
      end
    end
  end
end
