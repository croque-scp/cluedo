const gulp = require('gulp');
const coffee = require('gulp-coffee');
const babel = require('gulp-babel');
const log = require('fancy-log');
const postcss = require('gulp-postcss');
const rename = require('gulp-rename');
const cssimport = require('gulp-cssimport');
const postcssGridKiss = require('postcss-grid-kiss');
const postcssCssVariables = require('postcss-css-variables');
const cssnano = require('cssnano');
const exec = require('child_process').exec;
const through2 = require('through2');
const gutil = require('gulp-util');
const plumber = require('gulp-plumber');
const path = require('path');

gulp.task('events', function(done) {
  // Convert spreadsheet to events
  gulp.src('./src/events.xlsm')
    .pipe(plumber())
    .on('end', () => log("Found sheet"))
    .pipe(through2.obj((file, enc, cb) => {
      exec("./generate_dialogue.py", (err, stdout, stderr) => {
        if (err) { gutil.log(err); }
        file.contents = new Buffer(stdout);
        console.log(stderr);
        cb(err, file);
      });
    }))
    .on('end', () => log("Processed sheet"))
    .pipe(rename("events.temp.coffee"))
    .pipe(gulp.dest('./src/js/'))
    .on('end', () => log("Converted events sheet to coffeescript"))
    .on('end', () => done());
});

gulp.task('js', function(done) {
  // Pipe any js files (should be none in final build)
  gulp.src('./src/js/*.js')
    .pipe(gulp.dest('./dist/'))
    .on('end', () => log("Moved any JS files to dist"));
  // Convert coffee files
  gulp.src('./src/js/*.coffee', {sourcemaps: true})
    .pipe(rename(function(path) {
      if(path.basename === "events.temp") {
        path.basename = "events";
      };
    }))
    .pipe(coffee({bare: true}))
    .on('end', () => log("Converted coffee to JS"))
    .pipe(babel({presets: ['env']}))
    .on('end', () => log("Piped coffee through Babel"))
    .pipe(gulp.dest('./dist/'))
    .on('end', () => done());
});

gulp.task('css', function(done) {
  // XXX while css is not yet added
  done();
  return;
  // XXX
  // Post-process, minify and concatenate css files
  gulp.src('./src/css/root.css')
    .pipe(cssimport())
    .on('end', () => log("Resolving CSS imports"))
    .pipe(postcss([
      postcssCssVariables(),
      postcssGridKiss(),
      // cssnano(),
    ]))
    .on('end', () => log("Post-processing CSS"))
    .pipe(rename("maitreya.css"))
    .pipe(gulp.dest('./dist/'))
    .on('end', () => done());
});

gulp.task('static', function(done) {
  // Pipe images, html, json
  gulp.src('./src/images/*.*')
    .pipe(gulp.dest('./dist/'));
  gulp.src('./src/*.html')
    .pipe(gulp.dest('./dist/'));
  gulp.src('./src/js/*.json')
    .pipe(gulp.dest('./dist/'))
    .on('end', () => done());
});

gulp.task('default', gulp.series('events','js','css','static'));
