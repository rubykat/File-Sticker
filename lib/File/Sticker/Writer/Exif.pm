package File::Sticker::Writer::Exif;

=head1 NAME

File::Sticker::Writer::Exif - write and standardize meta-data from EXIF file

=head1 SYNOPSIS

    use File::Sticker::Writer::Exif;

    my $obj = File::Sticker::Writer::Exif->new(%args);

    my %meta = $obj->write_meta(%args);

=head1 DESCRIPTION

This will write meta-data from EXIF files, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

=cut

use common::sense;
use File::LibMagic;
use Image::ExifTool qw(:Public);

use parent qw(File::Sticker::Writer);

=head1 METHODS

=head2 allowed_file

If this writer can be used for the given file, then this returns true.
File must be one of: an image or PDF. (ExifTool can't write to EPUB)

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;

    my $ft = $self->{file_magic}->info_from_filename($file);
    if ($ft->{mime_type} =~ /(image|pdf)/)
    {
        return 1;
    }
    return 0;
} # allowed_file

=head2 known_fields

Returns the fields which this writer knows about.

    my $known_fields = $writer->known_fields();

=cut

sub known_fields {
    my $self = shift;

    return {
        url=>1,
        creator=>1,
        title=>1,
        description=>1,
        tags=>1};
} # known_fields

=head2 write_meta

Write the meta-data to the given file.

    $obj->write_meta(filename=>$filename, meta=>\%meta);

=cut

sub write_meta {
    my $self = shift;
    my %args = @_;

    my $filename = $args{filename};

} # write_meta

=cut

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Writer
__END__
