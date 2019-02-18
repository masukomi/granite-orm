{% for adapter in SandstoneExample::ADAPTERS %}
  {% model_constant = "Review#{adapter.camelcase.id}".id %}
  {% empty_model_constant = "Empty#{adapter.camelcase.id}".id %}

  describe "{{ adapter.id }} #casting_to_fields" do
    it "casts string to int" do
      model = {{ model_constant }}.new({ "downvotes" => "32" })
      model.downvotes.should eq 32
    end

    it "generates an error if casting fails" do
      model = {{ model_constant }}.new({ "downvotes" => "" })
      model.errors.size.should eq 1
    end

    it "compiles with empty fields" do
      model = {{ empty_model_constant }}.new
      model.should_not be_nil
    end
  end
{% end %}
