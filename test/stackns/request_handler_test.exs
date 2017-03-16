defmodule Stackns.RequestHandlerTest do
  use ExUnit.Case
  doctest Stackns.RequestHandler

  setup do
    :ets.new(:hosts, [:public, :named_table, :bag])
    { :ok, pid } = Stackns.RequestHandler.start_link( %{ dns: {"8.8.8.8", 53}, hosts: :hosts })
    { :ok, %{server: pid} }
  end

  test ".resolve(req, dns)" do
    req = %DNS.Record{anlist: [], arlist: [{:dns_rr_opt, '.', :opt, 4096, 0, 0, 0, ""}], header: %DNS.Header{aa: false, id: 55920, opcode: :query, pr: false, qr: false, ra: false, rcode: 0, rd: true, tc: false}, nslist: [], qdlist: [%DNS.Query{class: :in, domain: 'google.com', type: :a}]}
    resp = Stackns.RequestHandler.resolve(req, {"8.8.8.8", 53})
    assert resp.anlist != []
  end

  test ".query(req) should handle local domain" do
    :ets.insert(:hosts, { 'dummy', "9.9.9.9" })
    req = %DNS.Record{anlist: [], arlist: [{:dns_rr_opt, '.', :opt, 4096, 0, 0, 0, ""}], header: %DNS.Header{aa: false, id: 55920, opcode: :query, pr: false, qr: false, ra: false, rcode: 0, rd: true, tc: false}, nslist: [], qdlist: [%DNS.Query{class: :in, domain: 'dummy', type: :a}]}
    resp = Stackns.RequestHandler.query(req)
    assert resp.anlist != []
  end

  test ".query(req) should return empty result for noexist domains" do
    req = %DNS.Record{anlist: [], arlist: [{:dns_rr_opt, '.', :opt, 4096, 0, 0, 0, ""}], header: %DNS.Header{aa: false, id: 55920, opcode: :query, pr: false, qr: false, ra: false, rcode: 0, rd: true, tc: false}, nslist: [], qdlist: [%DNS.Query{class: :in, domain: 'dummy1', type: :a}]}
    resp = Stackns.RequestHandler.query(req)
    assert resp.anlist == []
  end
end
