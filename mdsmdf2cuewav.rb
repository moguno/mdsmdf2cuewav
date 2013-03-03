#! /usr/bin/ruby

LAYOUT_MDS_HEADER = [
	[:signature, "A", 16],
	[:version, "A", 3],
	[:dummy, "c", 1],
	[:version2, "v", 3],
	[:dummy2, "c", 70],
	[:pregap_corr, "V", 1],
	[:num_sectors, "V", 1],
	[:dummy4, "v", 1],
	[:num_entries, "c", 1],
	[:num_leadin, "c", 1],
	[:num_sessions, "c", 1],
	[:dummy5, "c", 1],
	[:num_tracks, "c", 1],
	[:dummy6, "c", 5],
	[:ofs_entries, "V", 1]
]

LAYOUT_MDS_DATABLOCK = [
	[:mode, "v", 1],
	[:flags, "v", 1],
	[:track, "c", 1],
	[:dummy, "c", 4],
	[:min, "c", 1],
	[:sec, "c", 1],
	[:frame, "c", 1],
	[:ofs_extra, "V", 1],
	[:sector_size, "v", 1],
	[:dummy2, "c", 18],
	[:sector, "V", 1],
	[:offset, "V", 2],
	[:session, "c", 1],
	[:dummy3, "c", 3],
	[:ofs_footer, "V", 1],
	[:dummy4, "c", 24],
]

LAYOUT_WAVE_RIFF = [
	[:riff_hed, "A", 4],
	[:file_size, "V", 1],
	[:wave_hed, "A", 4],
	[:fmt_hed, "A", 4],
	[:fmt_size, "V", 1],
	[:id, "v", 1],
	[:channels, "v", 1],
	[:sample_rate, "V", 1],
	[:speed, "V", 1],
	[:block_size, "v", 1],
	[:bits_per_sample, "v", 1],
	[:data_hed, "A", 4],
	[:data_size, "V", 1],
]


def dump(layout, data)
	format = ""
	values = []

	layout.each { |item|
		format = format + item[1] + item[2].to_s
		values << data[item[0]]
	}

	return values.pack(format)
end


def load(fp, layout)
	result = {}

	format = layout.inject("") { |fmt, item| fmt + item[1] + item[2].to_s }

	size = layout.inject(0) { |sz, item|
		base = case item[1]
			when "A" then 1
			when "c" then 1
			when "v" then 2
			when "V" then 4
		end

		base *= item[2]

		sz += base
	}

	values = fp.read(size).unpack(format)
	i = 0

	layout.each { |item|
		if item[1] != "A" && item[2] != 1 then
			tmp = []

			(0..(item[2] - 1)).each { |j|
				tmp << values[i + j]
			}

			result[item[0]] = tmp
			i += item[2]
		else
			result[item[0]] = values[i]
			i += 1
		end
	}

	return result
end


def make_riff_header(wave_size)
	hed = {}

	hed[:riff_hed] = "RIFF"
	hed[:file_size] = 48 + wave_size - 8
	hed[:wave_hed] = "WAVE"
	hed[:fmt_hed] = "fmt"
	hed[:fmt_size] = 16
	hed[:id] = 1
	hed[:channels] = 2
	hed[:sample_rate] = 44100
	hed[:speed] = 176400
	hed[:block_size] = 4
	hed[:bits_per_sample] = 16
	hed[:data_hed] = "data"
	hed[:data_size] = wave_size

	return dump(LAYOUT_WAVE_RIFF, hed)
end


def mdf2wav(mdf_file, wav_file)
	File.open(wav_file, "w") { |fp|
		File.open(mdf_file) { |fp2|
			fp.print(make_riff_header(fp2.stat.size))
			fp.print(fp2.read)
		}
	}
end


def create_cue(mds_file, wav_file, cue_file)
	header = nil

	File.open(mds_file, "r") { |fp|
		header = load(fp, LAYOUT_MDS_HEADER)

		header[:num_leadin].times { 
			data_block = load(fp, LAYOUT_MDS_DATABLOCK)
		}

		File.open(cue_file, "w") { |fp2|
			fp2.puts("FILE \"#{wav_file}\" WAVE")

			header[:num_tracks].times { 
				data_block = load(fp, LAYOUT_MDS_DATABLOCK)

				sec = data_block[:min] * 60 + data_block[:sec] - 2 

				fp2.puts(sprintf("  TRACK %02d AUDIO", data_block[:track]))
				fp2.puts(sprintf("    INDEX 01 %02d:%02d:%02d", sec / 60, sec % 60, data_block[:frame]))
			}
		}
	}
end


begin
	if ARGV.length <= 0 then
		raise "usage: #{__FILE__} .mdsFile"
	end

	if !(ARGV[0] =~ /\.mds$/i) then
		raise "Invalid mds file"
	end

	if !File.exists?(ARGV[0]) then
		raise "mds file not found"
	end

	Dir.chdir(File.dirname(ARGV[0]))

	ARGV[0] =~ /^(.+).mds$/i

	mds_file = File.basename($1 + ".mds")
	mdf_file = File.basename($1 + ".mdf")
	wav_file = File.basename($1 + ".wav")
	cue_file = File.basename($1 + ".cue")

	if !File.exists?(mdf_file) then
		raise "mdf file not found"
	end

	create_cue(mds_file, wav_file, cue_file)

	mdf2wav(mdf_file, wav_file)

rescue => e
	STDERR.puts(e)
end
