%% ADD THE SIX ADDITIONAL EARTHQUAKE RECORDS
% Downloads public acceleration records, converts acceleration from g to
% m/s^2, and appends them to earthquakes.mat as [time, acceleration].

clear;
clc;

script_dir = fileparts(mfilename('fullpath'));
mat_file = fullfile(script_dir, 'earthquakes.mat');
assert(isfile(mat_file), 'Earthquake file not found: %s', mat_file);

g_si = 9.80665;
data = load(mat_file);

definitions = {
    'chi_chi', ...
    'https://raw.githubusercontent.com/Panchatantra/EQSignal/master/EQSignal/data/CHICHI-ILA004-N.at2', ...
    'ILA004', 'N', 1.0;
    'imperial_valley', ...
    'https://raw.githubusercontent.com/OpenSees/OpenSees/master/Workshops/OpenSeesDays/Steel2dModels/Oak_2_50_5_FN.AT2', ...
    'El Centro Meloland Overpass', 'FN, azimuth 233 degrees', 2.4072;
    'landers', ...
    'https://raw.githubusercontent.com/u-anurag/OpenSees-Examples/master/DynamicAnalysis/Riverdale_NGAW2/RSN850_LANDERS_DSP000.AT2', ...
    'Desert Hot Springs', '000', 1.0;
    'tabas', ...
    'https://raw.githubusercontent.com/u-anurag/OpenSees-Examples/master/DynamicAnalysis/Riverdale_NGAW2/RSN138_TABAS_BOS-V1.AT2', ...
    'Boshrooyeh', 'V1', 1.0;
    'san_fernando', ...
    'https://raw.githubusercontent.com/GeorgePapazafeiropoulos/PEER-Ground-Motion-Data-Base-Reader/master/RSN70_SFERN_L01021.AT2', ...
    'Lake Hughes #1', '021', 1.0;
    };

metadata = struct('field', {}, 'name', {}, 'station', {}, 'component', {}, ...
    'source', {}, 'source_scale_removed', {}, 'acceleration_unit', {});

for record_id = 1:size(definitions, 1)
    field = definitions{record_id, 1};
    source = definitions{record_id, 2};
    record = readPeerAt2(source);
    source_scale = definitions{record_id, 5};
    data.(field) = [record.time, record.acceleration_g*g_si/source_scale];

    metadata(end+1) = makeMetadata(field, field, definitions{record_id, 3}, ... %#ok<SAGROW>
        definitions{record_id, 4}, source, source_scale);
end

tohoku_source = ['https://dinamico2.unibg.it/erizzi/Archivio_FDIS/Data/' ...
    'Dati_Terremoto_Japan/MYG0041103111446_NS.txt'];
record = readTohokuText(tohoku_source);
% Despite the text header saying "g", its approximately 2649-unit peak is
% the documented acceleration in gal (cm/s^2), so convert it to m/s^2.
data.tohoku = [record.time, record.acceleration_cmps2/100];
metadata(end+1) = makeMetadata('tohoku', 'Tohoku 2011', ...
    'K-NET Tsukidate MYG004', 'NS', tohoku_source, 1.0);

data.earthquake_names = {'El Centro 1940', 'Northridge 1994', 'Kobe 1995', ...
    'Loma Prieta 1989', 'Chi-Chi 1999', 'Imperial Valley 1979', ...
    'Landers 1992', 'Tabas 1978', 'San Fernando 1971', 'Tohoku 2011'};
data.earthquake_fields = {'el_centro', 'northridge', 'kobe', 'loma_prieta', ...
    'chi_chi', 'imperial_valley', 'landers', 'tabas', ...
    'san_fernando', 'tohoku'};
data.earthquake_units = {'time [s]', 'acceleration [m/s^2]'};
data.additional_record_metadata = metadata;

save(mat_file, '-struct', 'data');
fprintf('Added six records to %s\n', mat_file);

function record = readPeerAt2(source)
text = webread(source);
lines = splitlines(string(text));
header_id = find(contains(upper(lines), 'NPTS') & contains(upper(lines), 'DT'), 1, 'first');
assert(~isempty(header_id), 'Could not find NPTS/DT header in %s', source);

header = char(lines(header_id));
tokens = regexp(header, ...
    'NPTS\s*=\s*(\d+)\s*,?\s*DT\s*=\s*([0-9.Ee+-]+)', 'tokens', 'once');
if isempty(tokens)
    tokens = regexp(header, ...
        '(\d+)\s+([0-9.Ee+-]+)\s+NPTS\s*,?\s*DT', 'tokens', 'once');
end
assert(~isempty(tokens), 'Could not parse NPTS/DT header in %s', source);

n_point = str2double(tokens{1});
dt = str2double(tokens{2});
values = sscanf(char(join(lines(header_id+1:end), newline)), '%f');
assert(numel(values) >= n_point, 'Record %s contains fewer samples than declared.', source);

record.time = (0:n_point-1)'*dt;
record.acceleration_g = values(1:n_point);
end

function record = readTohokuText(source)
text = webread(source);
lines = splitlines(string(text));
dt_line = lines(find(contains(lines, 'dt ='), 1, 'first'));
dt_token = regexp(char(dt_line), 'dt\s*=\s*([0-9.]+)', 'tokens', 'once');
separator_id = find(contains(lines, '---'), 1, 'first');
assert(~isempty(dt_token) && ~isempty(separator_id), ...
    'Could not parse the Tohoku record header.');

dt = str2double(dt_token{1});
values = sscanf(char(join(lines(separator_id+1:end), newline)), '%f');
record.time = (0:numel(values)-1)'*dt;
record.acceleration_cmps2 = values;
end

function item = makeMetadata(field, name, station, component, source, source_scale)
item = struct('field', field, 'name', name, 'station', station, ...
    'component', component, 'source', source, ...
    'source_scale_removed', source_scale, 'acceleration_unit', 'm/s^2');
end
