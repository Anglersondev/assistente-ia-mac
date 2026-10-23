// macOS JavaScript for Automation. Reads only public model metadata from CLI cache.
ObjC.import('Foundation');
function clean(value) { return String(value || '').replace(/[\t\r\n\x00-\x1f]/g, ' ').slice(0, 180); }
function run(argv) {
  if (!argv.length) return '';
  try {
    var raw = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null);
    if (!raw) return '';
    var catalog = JSON.parse(ObjC.unwrap(raw));
    if (!Array.isArray(catalog.models)) return '';
    return catalog.models.filter(function(m) {
      return m && m.visibility === 'list' && typeof m.slug === 'string';
    }).slice(0, 40).map(function(m) {
      var levels = Array.isArray(m.supported_reasoning_levels) ? m.supported_reasoning_levels.map(function(v) {
        return v.effort;
      }).filter(function(v) { return /^(low|medium|high|xhigh|max|ultra)$/.test(v); }).join(',') : '';
      return [clean(m.slug), clean(m.display_name || m.slug), levels || 'default'].join('\t');
    }).join('\n');
  } catch (e) { return ''; }
}
