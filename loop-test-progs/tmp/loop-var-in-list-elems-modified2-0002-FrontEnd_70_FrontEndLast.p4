#include <core.p4>
#define V1MODEL_VERSION 20180101
#include <v1model.p4>

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

struct metadata_t {
}

struct headers_t {
    ethernet_t ethernet;
}

parser parserImpl(packet_in packet, out headers_t hdr, inout metadata_t meta, inout standard_metadata_t stdmeta) {
    state start {
        packet.extract<ethernet_t>(hdr.ethernet);
        transition accept;
    }
}

control ingressImpl(inout headers_t hdr, inout metadata_t meta, inout standard_metadata_t stdmeta) {
    @name("ingressImpl.n") bit<8> n_0;
    @name("ingressImpl.m") bit<8> m_0;
    @name("ingressImpl.p") bit<8> p_0;
    @name("ingressImpl.q") bit<8> q_0;
    @name("ingressImpl.i") bit<8> i_0;
    apply {
        n_0 = 8w0;
        m_0 = hdr.ethernet.dstAddr[15:8];
        if (hdr.ethernet.etherType == 16w5) {
            p_0 = hdr.ethernet.dstAddr[23:16];
        } else {
            p_0 = ~hdr.ethernet.dstAddr[23:16];
        }
        q_0 = hdr.ethernet.dstAddr[31:24];
        for (@name("ingressImpl.i") bit<8> i_0 in (list<bit<8>>){8w1,8w2,m_0,p_0,q_0}) {
            n_0 = n_0 + i_0;
            m_0 = 8w32;
            if (hdr.ethernet.etherType == 16w5) {
                p_0 = 8w64;
            } else {
                p_0 = 8w1;
            }
            q_0 = 8w128;
        }
        hdr.ethernet.srcAddr[7:0] = n_0;
        hdr.ethernet.srcAddr[15:8] = m_0;
        hdr.ethernet.srcAddr[23:16] = p_0;
        hdr.ethernet.srcAddr[31:24] = q_0;
        stdmeta.egress_spec = 9w1;
    }
}

control egressImpl(inout headers_t hdr, inout metadata_t meta, inout standard_metadata_t stdmeta) {
    apply {
    }
}

control deparserImpl(packet_out packet, in headers_t hdr) {
    apply {
        packet.emit<ethernet_t>(hdr.ethernet);
    }
}

control verifyChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply {
    }
}

control updateChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply {
    }
}

V1Switch<headers_t, metadata_t>(parserImpl(), verifyChecksum(), ingressImpl(), egressImpl(), updateChecksum(), deparserImpl()) main;