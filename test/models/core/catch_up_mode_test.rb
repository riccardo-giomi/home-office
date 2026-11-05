require "test_helper"

describe Core::CatchUpMode do
  it "defaults to lazy" do
    _(Core::CatchUpMode.mode(nil)).must_equal :lazy
    _(Core::CatchUpMode.mode("")).must_equal :lazy
  end

  it "takes lazy, job and off, in any case" do
    _(Core::CatchUpMode.mode(" Off ")).must_equal :off
    _(Core::CatchUpMode.mode("JOB")).must_equal :job
    _(Core::CatchUpMode.mode("LAZY")).must_equal :lazy
  end

  it "refuses another word, naming the ones it takes" do
    error = _ { Core::CatchUpMode.mode("both") }.must_raise(ArgumentError)
    _(error.message).must_match(/HOME_OFFICE_CATCH_UP.*lazy, job, off/)
  end

  it "is lazy on a request in lazy mode only" do
    {"lazy" => true, "job" => false, "off" => false}.each do |word, lazy|
      use_catch_up word
      _(Core::CatchUpMode.lazy?).must_equal lazy
    end
  end

  it "runs the job in job mode only" do
    {"lazy" => false, "job" => true, "off" => false}.each do |word, job|
      use_catch_up word
      _(Core::CatchUpMode.job?).must_equal job
    end
  end
end
