# frozen_string_literal: true

module Sidekiq
  module Sideline
    module CallbackStorage
      class Base
        def store(_callbacks)
          raise NotImplementedError
        end

        def retrieve(_ref)
          raise NotImplementedError
        end
      end
    end
  end
end
