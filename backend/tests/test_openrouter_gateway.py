from app.services.openrouter_gateway import FREE_ROUTER_ID, is_free_model


def test_free_model_filter_is_explicit():
    assert is_free_model("meta-llama/llama-3.1-8b-instruct:free")
    assert is_free_model(FREE_ROUTER_ID)
    assert not is_free_model("openai/gpt-4o")
    assert not is_free_model("anthropic/claude-3.5-sonnet")


def test_only_free_suffix_is_accepted():
    assert is_free_model("provider/model:free")
    assert not is_free_model("provider/model")
