"""Unit tests that need no database: password hashing and token digests."""
from app.security import hash_password, hash_token, new_session_token, verify_password


def test_password_round_trip():
    h = hash_password("correct horse battery staple")
    assert verify_password("correct horse battery staple", h)
    assert not verify_password("wrong", h)


def test_verify_password_rejects_null_hash():
    assert verify_password("anything", None) is False


def test_session_token_is_unique_and_digested():
    t1 = new_session_token()
    t2 = new_session_token()
    assert t1 != t2
    assert hash_token(t1) != t1  # digest is not the raw token
    assert hash_token(t1) == hash_token(t1)  # deterministic
    assert len(hash_token(t1)) == 64  # sha256 hex
