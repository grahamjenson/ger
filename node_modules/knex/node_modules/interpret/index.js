var extensions = {
  '.co': 'coco',
  '.coffee': 'coffee-script/register',
  '.csv': 'require-csv',
  '.iced': 'iced-coffee-script/register',
  '.ini': 'require-ini',
  '.js': null,
  '.json': null,
  '.litcoffee': 'coffee-script/register',
  '.ls': 'livescript',
  '.toml': 'toml-require',
  '.xml': 'require-xml',
  '.yaml': 'require-yaml',
  '.yml': 'require-yaml'
};

var register = {
  'toml-require': function (module) {
    module.install();
  }
};

var jsVariantExtensions = [
  '.co',
  '.coffee',
  '.iced',
  '.js',
  '.litcoffee',
  '.ls'
];

module.exports = {
  extensions: extensions,
  register: register,
  jsVariants: jsVariantExtensions.reduce(function (result, ext) {
    result[ext] = extensions[ext];
    return result;
  }, {})
};
