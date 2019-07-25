%% ====== SET PARAMS ==========
k=1;
n=1;
folder='D:\Dropbox\Working\mquic-latency\logs\';
distribution_name = 'on5-off3';
global exp_name;
exp_name = 'app-delay-quic-c-400-c-1252';
log_surfix= '-timestamp.log';
pcap_surfix= '-pcap.dat';

global RTT; RTT=1;
global TIME_RESOLUTION; TIME_RESOLUTION = .1;

set(0,'DefaultFigureWindowStyle','docked');
set(0,'DefaultLineLineWidth',1.5);
set(0,'DefaultAxesXGrid','off','DefaultAxesYGrid','on','DefaultAxesGridLineStyle','--');
set(0,'defaultAxesPlotboxAspectRatio',[1.618,1,1]);
set(0,'defaultAxesPlotboxAspectRatioMode','manual');
set(0,'DefaultFigureColormap',feval('colorcube'));

%% =========== Load DATA ==============
scheds=["lrtt"];
labels=["lrtt","rr","opp"];

sched_latencies={};
server_dat={};
for j = 1:length(scheds)
    sched_latency=[];
    for i=k:n
         sched=convertStringsToChars(scheds(j));
         eval([sched '_client_dat = dlmread(strcat(folder,num2str(i),"-", scheds(j),"-",exp_name, "-client",log_surfix ));' ]);
         eval([sched '_server_dat = dlmread(strcat(folder,num2str(i),"-", scheds(j),"-",exp_name, "-server",log_surfix ));' ]);
         eval([sched '_client_dat = sortrows(' sched '_client_dat,1);']);
         eval([sched '_server_dat = sortrows(' sched '_server_dat,1);']);
         eval(['sched_latency = vertcat(sched_latency, ' sched '_server_dat(:,2) - ' sched '_client_dat(:,2));'] );
         eval(['server_dat{j} = sortrows(' sched '_server_dat,2)/10^9;']);
    end
    sched_latencies{length(sched_latencies)+1} = sched_latency/10^6;
end
pcap_labels=[];
%% ====== Load pcap ==========
% pcap_labels=["lrtt-pcap","rr-pcap","opp-pcap"];
% 
% for j = 1:length(scheds)
%     sched_latency=[];
%     for i=k:n
%          sched=convertStringsToChars(scheds(j));
%          eval([sched '_pcap_dat = dlmread(strcat(folder,num2str(i),"-", scheds(j),"-",exp_name,pcap_surfix ));' ]);
%                   
%          eval(['sched_latency = vertcat(sched_latency, ' sched '_pcap_dat(:,10));'] );
%          eval(['server_dat{j} = sortrows(' sched '_pcap_dat,2);']);
%     end
%     sched_latencies{length(sched_latencies)+1} = sched_latency*10^3;
% end


%% =========== plot DATA ==============
plotccdf([labels,pcap_labels],sched_latencies);
% plot_throughput(labels,server_dat);
% plot_subflows("Redundant",re_pcap_dat);
% plot_subflows("Lrtt",lrtt_pcap_dat);


%% =========== Functions Definition ==============
function[sorted_data] = sortData(raw_data)
    sorted_data = sortrows(raw_data,1);
end

function[]=plotccdf(labels,data)
global exp_name;

figure
for i=1:length(data)
    [xccdf,yccdf]=getccdf(data{i});
    plot(xccdf,yccdf);
    hold on;
end

xlabel('Latency (ms)') ;
ylabel('Probability P(X>x)');
title(strcat('CCDF-',exp_name));
legend(labels);
set(gca, 'YScale', 'log');
end

function[xccdf,yccdf] = getccdf(value)
[ycdf,xcdf] = cdfcalc(value);
xccdf = xcdf;
yccdf = 1-ycdf(1:end-1);

end

function[] = plot_throughput(labels,timestamp_data)
throughputs=[];
group = [];


for i=1:length(timestamp_data)
    figure
    thoughput=get_throughput(timestamp_data{i});
    throughputs=[throughputs;thoughput(:,2)];
    group=[group;i*ones(size(thoughput(:,2)))];
    plot(thoughput);
    hold on;
    legend(labels(i));
end

% boxplot(throughputs,group);

%set(gca,'XTickLabel',labels);
end

function[thoughput]=get_throughput(sched_dat)
global TIME_RESOLUTION;
TIME_COLUMM =6;
start_point = sched_dat(1,TIME_COLUMM);
end_point=sched_dat(end,TIME_COLUMM) ;
time_window= end_point - start_point;
thoughput = zeros(ceil(time_window)/TIME_RESOLUTION,2);

for i=1:size(thoughput)
    thoughput(i,1) = (i*TIME_RESOLUTION);
    
end

for i=1:size(sched_dat)
    relative_time = (sched_dat(i,TIME_COLUMM) - start_point)/TIME_RESOLUTION;
    thoughput(floor(relative_time)+1,2) = thoughput(floor(relative_time)+1,2)+ sched_dat(i,11)*8/TIME_RESOLUTION;
end

% trim the results
% thoughput = thoughput(20:end-20,:);
end

function[] = plot_subflows(plot_title,flow_data)

[sf_group,sf_senders] = findgroups(flow_data(:,3));
sf_throughput = splitapply(@(x){(get_throughput(x))},flow_data,sf_group);
figure
for i=1:size(sf_throughput(:,1))
    plot(sf_throughput{i,1}(:,1), sf_throughput{i,1}(:,2));
    hold on;
end
legend(dec2ip(sf_senders));

%     flow_throughput=get_throughput(flow_data);
%     plot(flow_throughput(:,1), flow_throughput(:,2));
%     hold on;
%     legend("All");


title(plot_title);

end
function[ip] = dec2ip(decip)
ip= strcat( num2str(bitand(bitshift(decip,-24), 255)) ,'.', num2str(bitand(bitshift(decip,-16), 255)) ,'.', num2str(bitand(bitshift(decip,-8), 255))  ,'.', num2str(bitand(bitshift(decip,0), 255)));
end