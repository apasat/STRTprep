##
## Step 3h - differential expression analysis
##

def step3h_diffexpN_sources(path)
  root = path.pathmap('%d')
  return ["out/byGene/samples.csv", "#{root}/reads.RData", "#{root}/nreads.RData"]
end

rule /diffexp[\d+]\.txt\.gz$/ =>
                         [->(path){ step3h_diffexpN_sources(path) }] do |t|
  idx = /diffexp([\d+])\.txt\.gz$/.match(t.name).to_a[1]
  sh "R --vanilla --quiet --args #{idx} #{t.source} #{t.sources[1]} #{t.sources[2]} #{t.name} #{DEFAULTS['DIFFEXP']} #{DEFAULTS['FLUCTUATION']} #{t.name.pathmap('%d')} < bin/_step3h_SAMstrt.R > #{t.name}.log 2>&1"
end

##

step3h_sources = ['out/byGene/reads.txt.gz',
                  'out/byGene/nreads.txt.gz',
                  'out/byGene/fluctuation.txt.gz']
begin
  infp = open('src/samples.csv', 'rt')
  colnames = infp.gets.rstrip.split(',')
  classes = colnames.select { |colname| /^CLASS\.\d+$/.match(colname) }
  classes.each do |cls|
    idx = /^CLASS\.(\d+)$/.match(cls).to_a[1]
    step3h_sources.push("out/byGene/diffexp#{idx}.txt.gz")
  end
  infp.close
end

def step3h_job(t)
  ofs = /regions/ =~ t.sources[3] ? 5 : 3
  
  annotation = nil
  regions = nil
  if ofs == 5
    regions = Hash.new
    infp = open("| gunzip -c #{t.sources[3]}")
    while line = infp.gets
      cols = line.rstrip.split(/\t/)
      regions[cols[3]] = "#{cols[0]}:#{cols[1].to_i+1}-#{cols[2]};#{cols[5]}"
    end
    infp.close
    
    annotation = Hash.new
    infp = open("| gunzip -c #{t.sources[4]}")
    while line = infp.gets
      cols = line.rstrip.split(/\t/)
      annotation[cols[0]] = cols[1..-1]
    end
    infp.close
  end
  
  diffexps = Hash.new
  header_diffexps = Array.new
  t.sources[ofs..-1].each_index do |idx|
    tmp = Hash.new
    infp = open("| gunzip -c #{t.sources[idx+ofs]}")
    header = infp.gets
    while line = infp.gets
      cols = line.rstrip.split(/\t/)
      tmp[cols[0]] = cols[1..-1].join(',')
    end
    infp.close
    infp = open("| gunzip -c #{t.sources[idx+ofs].sub('/diffexp', '/fluctuation_diffexp')}")
    header = infp.gets
    while line = infp.gets
      cols = line.rstrip.split(/\t/)
      tmp[cols[0]] = "#{tmp[cols[0]]},#{cols[1] != 'NA' ? cols[1] : 1}" if tmp.key?(cols[0])
    end
    infp.close
    diffexps[idx] = tmp
    header_diffexps.push("Score.#{idx}")
    header_diffexps.push("pvalue.#{idx}")
    header_diffexps.push("qvalue.#{idx}")
    header_diffexps.push("fluctuation.#{idx}")
  end

  fluctuation = Hash.new
  infp = open("| gunzip -c #{t.sources[2]}")
  header_fluctuation = infp.gets
  while line = infp.gets
    gene, pvalue = line.rstrip.split(/\t/)
    fluctuation[gene] = pvalue != 'NA' ? pvalue : 1
  end
  infp.close
  
  nreads = Hash.new
  infp = open("| gunzip -c #{t.sources[1]}")
  header_nreads = infp.gets.rstrip.split(/\t/)
  1.upto(header_nreads.length-1) do |i|
    header_nreads[i] = "N|#{header_nreads[i]}"
  end
  while line = infp.gets
    cols = line.rstrip.split(/\t/)
    nreads[cols[0]] = cols[1..-1]
  end
  infp.close

  outfp = open(t.name, 'w')
  infp = open("| gunzip -c #{t.source}")
  header_reads = infp.gets.rstrip.split(/\t/)
  1.upto(header_reads.length-1) do |i|
    header_reads[i] = "R|#{header_reads[i]}"
  end
  outfp.puts ([header_reads[0]] + (annotation.nil? ? [] : ['Region', 'Peak', 'Gene', 'Transcript', 'Location']) + ['fluctuation.global'] + header_diffexps + header_nreads[1..-1] + header_reads[1..-1]).join(',')
  while line = infp.gets
    cols = line.rstrip.split(/\t/)
    row_diffexps = Array.new
    diffexps.keys.sort.each do |idx|
      tmp = diffexps[idx]
      row_diffexps.push(tmp.key?(cols[0]) ? tmp[cols[0]] : ",,,")
    end
    outfp.puts ([cols[0]] + (regions.nil? ? [] : [regions[cols[0]]]) + (annotation.nil? ? [] : annotation[cols[0]]) + [fluctuation[cols[0]]] + row_diffexps + nreads[cols[0]] + cols[1..-1]).join(',')
  end
  infp.close
  outfp.close
end

file 'out/byGene/diffexp.csv' => step3h_sources do |t|
  step3h_job(t)
end

task :clean_step3h do
  sh "rm out/byGene/diffexp.csv"
end

task :diffexp => 'out/byGene/diffexp.csv'
