package fs

import (
	"os"
	"testing"

	"github.com/jacobsa/fuse"
	"github.com/jacobsa/fuse/fuseutil"
	"github.com/koding/fuseklient/transport"
	. "github.com/smartystreets/goconvey/convey"
)

func TestDir(t *testing.T) {
	Convey("NewDir", t, func() {
		Convey("It should initialize new directory", func() {
			d := newDir()

			Convey("It should initialize entries list and map", func() {
				So(len(d.Entries), ShouldEqual, 0)
				So(len(d.EntriesList), ShouldEqual, 0)
			})
		})
	})

	Convey("Dir#ReadEntries", t, func() {
		Convey("It should return entries fetched from remote", func() {
			d := newDir()

			entries, err := d.ReadEntries(0)
			So(err, ShouldBeNil)
			So(len(entries), ShouldEqual, 2)
		})

		Convey("It should not fetch entries from remote if entries alrady exists", func() {
			d := newDir()

			entries, err := d.ReadEntries(0)
			So(err, ShouldBeNil)
			So(len(entries), ShouldEqual, 2)

			d.Transport = &fakeTransport{}

			entries, err = d.ReadEntries(0)
			So(err, ShouldBeNil)
			So(len(entries), ShouldEqual, 2)
		})

		Convey("It should return error if offset is greater than length of contents", func() {
			d := newDir()
			d.Entries = []fuseutil.Dirent{fuseutil.Dirent{}}

			_, err := d.ReadEntries(2)
			So(err, ShouldEqual, fuse.EIO)
		})

		Convey("It should return only live entries from specified offset", func() {
			d := newDir()
			d.Entries = []fuseutil.Dirent{
				fuseutil.Dirent{Type: fuseutil.DT_Directory},
				fuseutil.Dirent{Type: fuseutil.DT_Unknown},
				fuseutil.Dirent{Type: fuseutil.DT_Directory},
			}

			entries, err := d.ReadEntries(1)
			So(err, ShouldBeNil)
			So(len(entries), ShouldEqual, 1)
		})

		Convey("It should return entries from specified offset", func() {
			d := newDir()
			d.Entries = []fuseutil.Dirent{
				fuseutil.Dirent{Type: fuseutil.DT_Directory},
				fuseutil.Dirent{Type: fuseutil.DT_Directory},
			}

			entries, err := d.ReadEntries(1)
			So(err, ShouldBeNil)
			So(len(entries), ShouldEqual, 1)
		})
	})

	Convey("Dir#FindEntry", t, func() {
		Convey("It should return specified entry if it exists", func() {
			d := newDir()
			n := NewEntry(d, "file")
			d.EntriesList = map[string]Node{"file": NewFile(n)}

			i, err := d.FindEntry("file")
			So(err, ShouldBeNil)

			child, ok := i.(*File)
			So(ok, ShouldBeTrue)
			So(child, ShouldHaveSameTypeAs, &File{})
		})

		Convey("It should return error if specified file doesn't exist", func() {
			d := newDir()
			d.EntriesList = map[string]Node{}

			_, err := d.FindEntry("file")
			So(err, ShouldEqual, fuse.ENOENT)
		})
	})

	Convey("Dir#FindEntryFile", t, func() {
		Convey("It should return specified file if it exists", func() {
			d := newDir()
			n := NewEntry(d, "file")
			d.EntriesList = map[string]Node{"file": NewFile(n)}

			child, err := d.FindEntryFile("file")
			So(err, ShouldBeNil)
			So(child.Name, ShouldEqual, "file")
		})

		Convey("It should return error if specified file doesn't exist", func() {
			d := newDir()

			_, err := d.FindEntryFile("file")
			So(err, ShouldEqual, fuse.ENOENT)
		})

		Convey("It should return error if specified entry is not a File", func() {
			d := newDir()
			n := NewEntry(d, "dir")
			d.EntriesList = map[string]Node{"dir": NewDir(n, d.IDGen)}

			_, err := d.FindEntryFile("dir")
			So(err, ShouldEqual, ErrNotAFile)
		})
	})

	Convey("Dir#FindEntryDir", t, func() {
		Convey("It should return specified directory if it exists", func() {
			d := newDir()
			n := NewEntry(d, "dir")
			d.EntriesList = map[string]Node{"dir": NewDir(n, d.IDGen)}

			child, err := d.FindEntryDir("dir")
			So(err, ShouldBeNil)
			So(child.Name, ShouldEqual, "dir")
		})

		Convey("It should return error if specified directory doesn't exist", func() {
			d := newDir()

			_, err := d.FindEntryDir("dir")
			So(err, ShouldEqual, fuse.ENOENT)
		})

		Convey("It should return error if specified entry is not a Dir", func() {
			d := newDir()
			n := NewEntry(d, "file")
			d.EntriesList = map[string]Node{"file": NewFile(n)}

			_, err := d.FindEntryDir("file")
			So(err, ShouldEqual, ErrNotADir)
		})
	})

	Convey("Dir#CreateEntryDir", t, func() {
		Convey("It should return error if entry already exists", func() {
			d := newDir()
			d.EntriesList = map[string]Node{"folder": NewFile(d.Entry)}

			_, err := d.CreateEntryDir("folder", os.FileMode(0700))
			So(err, ShouldEqual, fuse.EEXIST)
		})

		Convey("It should create directory", func() {
			d := newDir()
			m := os.FileMode(0700)

			_, err := d.CreateEntryDir("folder", m)
			So(err, ShouldBeNil)

			Convey("It should save directory in entries list", func() {
				i, ok := d.EntriesList["folder"]
				So(ok, ShouldBeTrue)

				dir, ok := i.(*Dir)
				So(ok, ShouldBeTrue)
				So(dir.Name, ShouldEqual, "folder")

				Convey("It should save directory with specified permissions", func() {
					So(dir.Attrs.Mode, ShouldEqual, m)
				})
			})

			Convey("It should save directory in entries map", func() {
				So(len(d.Entries), ShouldEqual, 1)
				So(d.Entries[0].Name, ShouldEqual, "folder")
			})
		})
	})

	Convey("Dir#CreateEntryFile", t, func() {
		Convey("It should return error if entry already exists", func() {
			d := newDir()
			d.EntriesList = map[string]Node{"file": NewFile(d.Entry)}

			_, err := d.CreateEntryFile("file", os.FileMode(0700))
			So(err, ShouldEqual, fuse.EEXIST)
		})

		Convey("It should create file", func() {
			d := newDir()
			m := os.FileMode(0755)

			_, err := d.CreateEntryFile("file", m)
			So(err, ShouldBeNil)

			Convey("It should save file in entries list", func() {
				i, ok := d.EntriesList["file"]
				So(ok, ShouldBeTrue)

				file, ok := i.(*File)
				So(ok, ShouldBeTrue)
				So(file.Name, ShouldEqual, "file")
				So(len(file.Content), ShouldEqual, 0)

				Convey("It should save file with specified permissions", func() {
					So(file.Attrs.Mode, ShouldEqual, m)
				})
			})

			Convey("It should save file in entries map", func() {
				So(len(d.Entries), ShouldEqual, 1)
				So(d.Entries[0].Name, ShouldEqual, "file")
			})
		})
	})

	Convey("Dir#MoveEntry", t, func() {
		Convey("It should return error if entry doesn't exists", func() {
			d := newDir()
			d.EntriesList = map[string]Node{}

			_, err := d.MoveEntry("file", "file1", nil)
			So(err, ShouldEqual, fuse.ENOENT)
		})

		Convey("It should move entry from one directory to another", func() {
			n := newDir()

			o := newDir()
			o.EntriesList = map[string]Node{"file": NewFile(NewEntry(o, "file"))}

			i, err := o.MoveEntry("file", "file1", n)
			So(err, ShouldBeNil)

			Convey("It should find new entry as same type as old", func() {
				file, ok := i.(*File)
				So(ok, ShouldBeTrue)
				So(file.Name, ShouldEqual, "file1")
			})

			Convey("It should find new entry in new directory", func() {
				i, ok := n.EntriesList["file1"]
				So(ok, ShouldBeTrue)

				file, ok := i.(*File)
				So(ok, ShouldBeTrue)
				So(file.Name, ShouldEqual, "file1")
			})
		})
	})

	Convey("Dir#RemoveEntry", t, func() {
		Convey("It should return error if entry doesn't exists", func() {
			d := newDir()

			_, err := d.RemoveEntry("file")
			So(err, ShouldEqual, fuse.ENOENT)
		})

		Convey("It should remove entry from File", func() {
			d := newDir()
			e := &entry{Name: "file", Type: fuseutil.DT_File, Mode: os.FileMode(0755)}

			_, err := d.initializeChild(e)
			So(err, ShouldBeNil)

			_, err = d.RemoveEntry("file")
			So(err, ShouldBeNil)

			Convey("It should set file entry type to unknown", func() {
				So(d.Entries[0].Type, ShouldEqual, fuseutil.DT_Unknown)
			})

			Convey("It should remove entry from entries map", func() {
				_, ok := d.EntriesList["file"]
				So(ok, ShouldBeFalse)
			})
		})
	})

	Convey("Dir#updateEntriesFromRemote", t, func() {
		Convey("It should fetch directory entries from remote", func() {
			d := newDir()
			d.Entries = []fuseutil.Dirent{}
			d.EntriesList = map[string]Node{}

			err := d.updateEntriesFromRemote()
			So(err, ShouldBeNil)

			Convey("It should update entries list and map", func() {
				So(len(d.Entries), ShouldEqual, 2)
				So(len(d.EntriesList), ShouldEqual, 2)
			})

			Convey("It should set file child entry in map", func() {
				i, ok := d.EntriesList["file"]
				So(ok, ShouldBeTrue)

				child, ok := i.(*File)
				So(ok, ShouldBeTrue)
				So(child, ShouldHaveSameTypeAs, &File{})
			})

			Convey("It should set directory child entry in map", func() {
				i, ok := d.EntriesList["folder"]
				So(ok, ShouldBeTrue)

				child, ok := i.(*Dir)
				So(ok, ShouldBeTrue)
				So(child, ShouldHaveSameTypeAs, &Dir{})
			})
		})
	})

	Convey("Dir#getEntriesFromRemote", t, func() {
		Convey("It should fetch dir entries from remote", func() {
			d := newDir()

			entries, err := d.getEntriesFromRemote()
			So(err, ShouldBeNil)
			So(len(entries), ShouldEqual, 2)

			dir, file := entries[0], entries[1]

			Convey("It should unmarshal fetched entry into directory", func() {
				So(dir.Type, ShouldEqual, fuseutil.DT_Directory)
				So(dir.Name, ShouldEqual, "folder")
				So(dir.Offset, ShouldEqual, 0)
				So(dir.Size, ShouldEqual, 1)
			})

			Convey("It should unmarshal fetched entry into file", func() {
				So(file.Type, ShouldEqual, fuseutil.DT_File)
				So(file.Name, ShouldEqual, "file")
				So(file.Offset, ShouldEqual, 0)
				So(file.Size, ShouldEqual, 2)
			})
		})
	})

	Convey("Dir#initializeChild", t, func() {
		Convey("It should initialize a Dir if specified entry is a directory", func() {
			d := newDir()
			e := &entry{Name: "dir", Type: fuseutil.DT_Directory, Mode: 0700 | os.ModeDir}

			i, err := d.initializeChild(e)
			So(err, ShouldBeNil)

			child, ok := i.(*Dir)
			So(ok, ShouldBeTrue)
			So(child, ShouldHaveSameTypeAs, &Dir{})
		})

		Convey("It should initialize a File if specified entry is a file", func() {
			d := newDir()
			e := &entry{Name: "file", Type: fuseutil.DT_File, Mode: os.FileMode(0755)}

			i, err := d.initializeChild(e)
			So(err, ShouldBeNil)

			child, ok := i.(*File)
			So(ok, ShouldBeTrue)
			So(child, ShouldHaveSameTypeAs, &File{})
		})

		Convey("It should initialize child entry", func() {
			d := newDir()
			e := &entry{Name: "dir", Type: fuseutil.DT_Directory, Mode: 0700 | os.ModeDir, Size: 1}

			i, err := d.initializeChild(e)
			So(err, ShouldBeNil)

			child, ok := i.(*Dir)
			So(ok, ShouldBeTrue)

			Convey("It should set parent for child entry", func() {
				So(child.Parent, ShouldEqual, d)
			})

			Convey("It should set id for child entry", func() {
				So(child.ID, ShouldEqual, 2)
			})

			Convey("It should set local path for child entry nested in parent", func() {
				So(child.LocalPath, ShouldEqual, "/local/dir")
			})

			Convey("It should set remote path for child entry nested in parent", func() {
				So(child.RemotePath, ShouldEqual, "/remote/dir")
			})

			Convey("It should set specificed name and entry type for child entry", func() {
				So(child.Name, ShouldEqual, "dir")
			})

			Convey("It should copy over only relevant parent attrs for child entry", func() {
				cAttrs, dAttrs := child.Attrs, d.Attrs

				So(cAttrs.Size, ShouldEqual, 1)
				So(cAttrs.Nlink, ShouldEqual, 0)
				So(cAttrs.Uid, ShouldEqual, dAttrs.Uid)
				So(cAttrs.Gid, ShouldEqual, dAttrs.Gid)
				So(cAttrs.Mode, ShouldEqual, 0700|os.ModeDir)

				So(cAttrs.Atime.IsZero(), ShouldBeFalse)
				So(cAttrs.Mtime.IsZero(), ShouldBeFalse)
				So(cAttrs.Ctime.IsZero(), ShouldBeFalse)
				So(cAttrs.Crtime.IsZero(), ShouldBeFalse)
			})

			Convey("It should set child entry in parent entries list", func() {
				So(len(d.Entries), ShouldEqual, 1)
				So(d.Entries[0].Name, ShouldEqual, "dir")
			})

			Convey("It should set child entry in parent entires map", func() {
				i, ok := d.EntriesList["dir"]
				So(ok, ShouldBeTrue)

				child, ok := i.(*Dir)
				So(ok, ShouldBeTrue)

				So(len(d.Entries), ShouldEqual, 1)
				So(d.Entries[0].Inode, ShouldEqual, child.ID)
			})

			Convey("It should set time to entry time", func() {
			})
		})
	})

	Convey("Dir#removeChild", t, func() {
		Convey("It should remove an entry", func() {
			d := newDir()
			e := &entry{Name: "dir", Type: fuseutil.DT_Directory, Mode: 0700 | os.ModeDir}

			_, err := d.initializeChild(e)
			So(err, ShouldBeNil)

			err = d.removeChild("dir")
			So(err, ShouldBeNil)

			Convey("It should set child entry type to unknown", func() {
				So(d.Entries[0].Type, ShouldEqual, fuseutil.DT_Unknown)
			})

			Convey("It should remove child from entries map", func() {
				_, ok := d.EntriesList["dir"]
				So(ok, ShouldBeFalse)
			})
		})
	})
}

func newDir() *Dir {
	t := &fakeTransport{
		TripResponses: map[string]interface{}{
			"fs.rename":          true,
			"fs.createDirectory": true,
			"fs.writeFile":       1,
			"fs.remove":          true,
			"fs.readDirectory": transport.FsReadDirectoryRes{
				Files: []transport.FsGetInfoRes{
					transport.FsGetInfoRes{
						Exists:   true,
						FullPath: "/remote/folder",
						IsDir:    true,
						Mode:     os.FileMode(0700),
						Name:     "folder",
						Size:     1,
					},
					transport.FsGetInfoRes{
						Exists:   true,
						FullPath: "/remote/file",
						IsDir:    false,
						Mode:     os.FileMode(0755),
						Name:     "file",
						Size:     2,
					},
				},
			},
		},
	}
	n := NewRootEntry(t, "/remote", "/local")
	i := NewIDGen()

	return NewDir(n, i)
}
