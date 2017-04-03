defmodule Stackns.HostsTest do
  use ExUnit.Case
  doctest Stackns.Hosts
  import Stackns.Hosts

  test ".lookup should handle local domains" do
    res = lookup("maas")
    assert res != []
  end
end
