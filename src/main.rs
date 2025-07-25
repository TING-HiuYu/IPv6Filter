use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::sync::Arc;

use anyhow::Result;
use log::{debug, info, warn};
use tokio::net::UdpSocket;
use trust_dns_proto::op::{Message, OpCode, ResponseCode};
use trust_dns_proto::rr::{Name, RData, Record, RecordType};
use trust_dns_resolver::config::{ResolverConfig, ResolverOpts};
use trust_dns_resolver::TokioAsyncResolver;

/// DNS服务器配置
#[derive(Clone)]
pub struct DnsServerConfig {
    /// 监听地址
    pub listen_addr: SocketAddr,
    /// 上游DNS服务器
    pub upstream_servers: Vec<SocketAddr>,
    /// 是否过滤IPv6记录
    pub filter_ipv6: bool,
}

impl Default for DnsServerConfig {
    fn default() -> Self {
        Self {
            listen_addr: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 53),
            upstream_servers: vec![
                "8.8.8.8:53".parse().unwrap(),
                "8.8.4.4:53".parse().unwrap(),
            ],
            filter_ipv6: true,
        }
    }
}

/// DNS服务器
pub struct DnsServer {
    config: DnsServerConfig,
    resolver: TokioAsyncResolver,
}

impl DnsServer {
    pub fn new(config: DnsServerConfig) -> Result<Self> {
        // 配置上游解析器
        let mut resolver_config = ResolverConfig::new();
        for upstream in &config.upstream_servers {
            resolver_config.add_name_server(trust_dns_resolver::config::NameServerConfig {
                socket_addr: *upstream,
                protocol: trust_dns_resolver::config::Protocol::Udp,
                tls_dns_name: None,
                trust_negative_responses: false,
                bind_addr: None,
            });
        }

        let resolver = TokioAsyncResolver::tokio(resolver_config, ResolverOpts::default());

        Ok(Self { config, resolver })
    }

    /// 启动DNS服务器
    pub async fn start(&self) -> Result<()> {
        let socket = Arc::new(UdpSocket::bind(self.config.listen_addr).await?);
        info!("DNS服务器启动，监听地址: {}", self.config.listen_addr);

        let mut buf = [0u8; 512];
        loop {
            match socket.recv_from(&mut buf).await {
                Ok((len, addr)) => {
                    let data = buf[..len].to_vec();
                    let server = self.clone();
                    let socket_ref = socket.clone();
                    
                    tokio::spawn(async move {
                        if let Err(e) = server.handle_request(data, addr, socket_ref).await {
                            warn!("处理请求时出错: {}", e);
                        }
                    });
                }
                Err(e) => {
                    warn!("接收UDP数据包时出错: {}", e);
                }
            }
        }
    }

    /// 处理DNS请求
    async fn handle_request(
        &self,
        data: Vec<u8>,
        client_addr: SocketAddr,
        socket: Arc<UdpSocket>,
    ) -> Result<()> {
        let request = Message::from_vec(&data)?;
        debug!("收到来自 {} 的DNS请求: {:?}", client_addr, request);

        let response = self.process_query(request).await?;
        let response_bytes = response.to_vec()?;
        
        socket.send_to(&response_bytes, client_addr).await?;
        debug!("已向 {} 发送响应", client_addr);

        Ok(())
    }

    /// 处理DNS查询
    async fn process_query(&self, request: Message) -> Result<Message> {
        let mut response = Message::new();
        response.set_id(request.id());
        response.set_message_type(trust_dns_proto::op::MessageType::Response);
        response.set_op_code(OpCode::Query);
        response.set_recursion_desired(request.recursion_desired());
        response.set_recursion_available(true);

        if request.queries().is_empty() {
            response.set_response_code(ResponseCode::FormErr);
            return Ok(response);
        }

        let query = &request.queries()[0];
        let name = query.name();
        let record_type = query.query_type();

        debug!("查询域名: {}, 类型: {:?}", name, record_type);

        // 添加问题部分到响应
        response.add_query(query.clone());

        match self.resolve_query(name, record_type).await {
            Ok(records) => {
                let filtered_records = self.filter_records(name, records).await?;
                for record in filtered_records {
                    response.add_answer(record);
                }
                response.set_response_code(ResponseCode::NoError);
            }
            Err(e) => {
                warn!("解析查询失败 {}: {}", name, e);
                response.set_response_code(ResponseCode::ServFail);
            }
        }

        Ok(response)
    }

    /// 向上游服务器解析查询
    async fn resolve_query(&self, name: &Name, record_type: RecordType) -> Result<Vec<Record>> {
        let lookup_result = match record_type {
            RecordType::A => {
                let lookup = self.resolver.ipv4_lookup(name.to_string()).await?;
                lookup
                    .iter()
                    .map(|ip| {
                        Record::from_rdata(
                            name.clone(),
                            300, // TTL
                            RData::A(ip.clone()),
                        )
                    })
                    .collect()
            }
            RecordType::AAAA => {
                let lookup = self.resolver.ipv6_lookup(name.to_string()).await?;
                lookup
                    .iter()
                    .map(|ip| {
                        Record::from_rdata(
                            name.clone(),
                            300, // TTL
                            RData::AAAA(ip.clone()),
                        )
                    })
                    .collect()
            }
            RecordType::CNAME => {
                let lookup = self.resolver.lookup(name.to_string(), record_type).await?;
                lookup
                    .record_iter()
                    .map(|record| record.clone())
                    .collect()
            }
            _ => {
                let lookup = self.resolver.lookup(name.to_string(), record_type).await?;
                lookup
                    .record_iter()
                    .map(|record| record.clone())
                    .collect()
            }
        };

        Ok(lookup_result)
    }

    /// 过滤记录（根据配置决定是否移除IPv6记录）
    async fn filter_records(&self, name: &Name, records: Vec<Record>) -> Result<Vec<Record>> {
        if !self.config.filter_ipv6 {
            return Ok(records);
        }

        // 检查当前记录中是否有AAAA记录
        let has_aaaa_record = records.iter().any(|r| matches!(r.data(), Some(RData::AAAA(_))));
        
        if has_aaaa_record {
            // 如果有AAAA记录，检查该域名是否同时有A记录
            match self.resolve_query(name, RecordType::A).await {
                Ok(a_records) if !a_records.is_empty() => {
                    // 同时有A记录，这是双栈域名，丢弃AAAA记录
                    info!("检测到双栈域名 {}，丢弃AAAA记录", name);
                    return Ok(vec![]); // 返回空记录
                }
                _ => {
                    // 没有A记录，这是纯IPv6域名，保留AAAA记录
                    info!("检测到纯IPv6域名 {}，保留AAAA记录", name);
                }
            }
        }

        // 其他情况正常返回
        Ok(records)
    }
}

impl Clone for DnsServer {
    fn clone(&self) -> Self {
        Self {
            config: self.config.clone(),
            resolver: self.resolver.clone(),
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();

    let config = DnsServerConfig {
        listen_addr: "127.0.0.1:8053".parse()?, // 使用8053端口避免权限问题
        ..Default::default()
    };

    info!("启动DNS服务器配置:");
    info!("  监听地址: {}", config.listen_addr);
    info!("  上游服务器: {:?}", config.upstream_servers);
    info!("  过滤IPv6: {}", config.filter_ipv6);

    let server = DnsServer::new(config)?;
    server.start().await?;

    Ok(())
}
